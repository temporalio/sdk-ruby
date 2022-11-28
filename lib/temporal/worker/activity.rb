require 'temporal/worker/sync_worker'
require 'temporal/worker/activity_task_processor'

module Temporal
  class Worker
    class Activity
      def initialize(core_worker, converter, executor)
        @running = false
        @worker = SyncWorker.new(core_worker)
        @converter = converter
        @executor = executor
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

      attr_reader :worker, :converter, :executor

      def running?
        @running
      end

      def process_activity_task(task)
        queue = Queue.new

        executor.schedule do
          result = ActivityTaskProcessor.new(task).process
          queue << result
        end

        queue.pop
      end

      def send_completion_response(task_token, result)
        payload = converter.to_payload(result)
        worker.complete_activity_task_with_success(task_token, payload)
      end

      def send_failure_response(task_token, exception)
        failure = converter.to_failure(exception)
        worker.complete_activity_task_with_failure(task_token, failure)
      end

      def handle_start_activity(task_token, task)
        result = process_activity_task(task)
        send_completion_response(task_token, result)
      rescue StandardError => e
        send_failure_response(task_token, e)
      end

      def handle_cancel_activity(task_token, task)
        # TODO: pending implementation
      end
    end
  end
end
