require 'temporal/sdk/core/activity_task/activity_task_pb'
require 'temporal/sdk/core/core_interface_pb'

module Temporalio
  class Worker
    # This is a wrapper class for the Core Worker (provided via the Bridge) to abstract
    # away its async nature allowing other modules/classes to interact with it without
    # any callbacks (simplifying the code).
    #
    # CAUTION: This class will block the thread its running in unless it is used from
    #          within an Async reactor.
    #
    # @api private
    class SyncWorker
      def initialize(core_worker)
        @core_worker = core_worker
      end

      def poll_activity_task
        with_queue do |done|
          core_worker.poll_activity_task do |task, error|
            done.call(task && Coresdk::ActivityTask::ActivityTask.decode(task), error)
          end
        end
      end

      def complete_activity_task_with_success(task_token, payload)
        result = Coresdk::ActivityResult::ActivityExecutionResult.new(
          completed: Coresdk::ActivityResult::Success.new(result: payload),
        )

        complete_activity_task(task_token, result)
      end

      def complete_activity_task_with_failure(task_token, failure)
        result = Coresdk::ActivityResult::ActivityExecutionResult.new(
          failed: Coresdk::ActivityResult::Failure.new(failure: failure),
        )

        complete_activity_task(task_token, result)
      end

      def complete_activity_task_with_cancellation(task_token, failure)
        result = Coresdk::ActivityResult::ActivityExecutionResult.new(
          cancelled: Coresdk::ActivityResult::Cancellation.new(failure: failure),
        )

        complete_activity_task(task_token, result)
      end

      def record_activity_heartbeat(task_token, payloads)
        proto = Coresdk::ActivityHeartbeat.new(
          task_token: task_token,
          details: payloads,
        )
        encoded_proto = Coresdk::ActivityHeartbeat.encode(proto)

        core_worker.record_activity_heartbeat(encoded_proto)
      end

      private

      attr_reader :core_worker

      def with_queue(&block)
        queue = Queue.new
        done = ->(result, error = nil) { queue << [result, error] }
        block.call(done)
        (result, exception) = queue.pop
        raise exception if exception

        result
      end

      def complete_activity_task(task_token, result)
        proto = Coresdk::ActivityTaskCompletion.new(
          task_token: task_token,
          result: result,
        )
        encoded_proto = Coresdk::ActivityTaskCompletion.encode(proto)

        with_queue do |done|
          core_worker.complete_activity_task(encoded_proto, &done)
        end
      end
    end
  end
end
