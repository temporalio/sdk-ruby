require 'temporalio/error/failure'
require 'temporalio/errors'
require 'temporalio/interceptor'
require 'temporalio/interceptor/chain'
require 'temporalio/worker/activity_runner'

module Temporalio
  class Worker
    # @api private
    class ActivityWorker
      def initialize(
        task_queue,
        worker,
        activities,
        converter,
        interceptors,
        executor,
        graceful_timeout
      )
        @task_queue = task_queue
        @worker = worker
        @activities = prepare_activities(activities)
        @converter = converter
        @inbound_interceptors = Temporalio::Interceptor::Chain.new(
          Temporalio::Interceptor.filter(interceptors, :activity_inbound),
        )
        @outbound_interceptors = Temporalio::Interceptor::Chain.new(
          Temporalio::Interceptor.filter(interceptors, :activity_outbound),
        )
        @executor = executor
        @graceful_timeout = graceful_timeout
        @running_activities = {}
        @cancellations = []
        @drain_queue = Queue.new
      end

      def run(reactor)
        # @type var outstanding_tasks: Array[Async::Task]
        outstanding_tasks = []

        loop do
          activity_task = worker.poll_activity_task
          outstanding_tasks << reactor.async do |async_task|
            if activity_task.start
              handle_start_activity(activity_task.task_token, activity_task.start)
            elsif activity_task.cancel
              handle_cancel_activity(activity_task.task_token, activity_task.cancel)
            end
          ensure
            outstanding_tasks.delete(async_task)
          end
        end
      rescue Temporalio::Bridge::Error::WorkerShutdown
        # No need to re-raise this error, it's a part of a normal shutdown
      ensure
        outstanding_tasks.each(&:wait)
        @cancelation_task&.wait
        drain_queue.close
      end

      def setup_graceful_shutdown_timer(reactor)
        if graceful_timeout
          reactor.async do |async_task|
            @cancelation_task = async_task.async do
              sleep graceful_timeout
              @running_activities.each_value do |activity_runner|
                activity_runner.cancel('Worker is shutting down', by_request: false)
              end
            end
          end
        end
      end

      def drain
        drain_queue.pop
      end

      private

      attr_reader :task_queue, :worker, :activities, :converter, :inbound_interceptors,
                  :outbound_interceptors, :executor, :graceful_timeout, :running_activities,
                  :cancellations, :drain_queue

      def prepare_activities(activities)
        activities.each_with_object({}) do |activity, result|
          unless activity.ancestors.include?(Temporalio::Activity)
            raise ArgumentError, 'Activity must be a subclass of Temporalio::Activity'
          end

          if result[activity._name]
            raise ArgumentError, "More than one activity named #{activity._name}"
          end

          result[activity._name] = activity
          result
        end
      end

      def lookup_activity(activity_type)
        activities.fetch(activity_type) do
          activity_names = activities.keys.sort.join(', ')
          raise Temporalio::Error::ApplicationError.new(
            "Activity #{activity_type} is not registered on this worker, available activities: #{activity_names}",
            type: 'NotFoundError',
          )
        end
      end

      def run_activity(token, start)
        activity_class = lookup_activity(start.activity_type)
        runner = ActivityRunner.new(
          activity_class,
          start,
          task_queue,
          token,
          worker,
          converter,
          inbound_interceptors,
          outbound_interceptors,
        )
        running_activities[token] = runner
        queue = Queue.new

        executor.schedule do
          queue << runner.run
        end

        queue.pop
      rescue StandardError => e
        converter.to_failure(e)
      end

      def handle_start_activity(task_token, start)
        result = run_activity(task_token, start)

        case result
        when Temporalio::Api::Common::V1::Payload
          worker.complete_activity_task_with_success(task_token, result)
        when Temporalio::Api::Failure::V1::Failure
          # only respond with a cancellation when it was requested, otherwise it's a regular failure
          if result.canceled_failure_info && cancellations.include?(task_token)
            worker.complete_activity_task_with_cancellation(task_token, result)
          else
            worker.complete_activity_task_with_failure(task_token, result)
          end
        end

        running_activities.delete(task_token)
        cancellations.delete(task_token)
      end

      def handle_cancel_activity(task_token, _cancel)
        runner = running_activities.fetch(task_token) do
          # TODO: Use logger instead when implemented
          warn "Cannot find activity to cancel for token #{task_token}"
          return # early escape
        end

        cancellations << task_token
        runner&.cancel('Activity cancellation requested', by_request: true)
      end
    end
  end
end
