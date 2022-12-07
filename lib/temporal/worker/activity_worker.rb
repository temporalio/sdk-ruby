require 'temporal/error/failure'
require 'temporal/worker/sync_worker'
require 'temporal/worker/activity_runner'

module Temporal
  class Worker
    class ActivityWorker
      def initialize(task_queue, core_worker, activities, converter, executor)
        @running = false
        @task_queue = task_queue
        @worker = SyncWorker.new(core_worker)
        @activities = prepare_activities(activities)
        @converter = converter
        @executor = executor
        @running_activities = {}
      end

      def run(reactor)
        @running = true

        while running?
          activity_task = worker.poll_activity_task
          reactor.async do
            if activity_task.start
              handle_start_activity(activity_task.task_token, activity_task.start)
            elsif activity_task.cancel
              handle_cancel_activity(activity_task.task_token, activity_task.cancel)
            end
          end
        end
      end

      def shutdown
        @running = false
        executor.shutdown
        # TODO: core worker shutdown implementation pending
      end

      private

      attr_reader :task_queue, :worker, :activities, :converter, :executor, :running_activities

      def running?
        @running
      end

      def prepare_activities(activities)
        activities.each_with_object({}) do |activity, result|
          unless activity.ancestors.include?(Temporal::Activity)
            raise ArgumentError, 'Activity must be a subclass of Temporal::Activity'
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
          raise Temporal::Error::ApplicationError.new(
            "Activity #{activity_type} is not registered on this worker, available activities: #{activity_names}",
            type: 'NotFoundError',
          )
        end
      end

      def run_activity(token, start)
        activity_class = lookup_activity(start.activity_type)
        runner = ActivityRunner.new(activity_class, start, task_queue, token, worker, converter)
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
        if result.is_a?(Temporal::Api::Common::V1::Payload)
          worker.complete_activity_task_with_success(task_token, result)
        else
          worker.complete_activity_task_with_failure(task_token, result)
        end
        running_activities.delete(task_token)
      end

      def handle_cancel_activity(task_token, _cancel)
        runner = running_activities[task_token]
        # TODO: Warn of a missing activity if runner is absent
        runner.cancel
      end
    end
  end
end
