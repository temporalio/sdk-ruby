require 'temporal/sdk/core/activity_task/activity_task_pb'
require 'temporal/sdk/core/core_interface_pb'
require 'temporal/sdk/core/workflow_activation/workflow_activation_pb'
require 'temporal/sdk/core/workflow_completion/workflow_completion_pb'

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
            done.call(task && Temporalio::Bridge::Api::ActivityTask::ActivityTask.decode(task), error)
          end
        end
      end

      def complete_activity_task_with_success(task_token, payload)
        result = Temporalio::Bridge::Api::ActivityResult::ActivityExecutionResult.new(
          completed: Temporalio::Bridge::Api::ActivityResult::Success.new(result: payload),
        )

        complete_activity_task(task_token, result)
      end

      def complete_activity_task_with_failure(task_token, failure)
        result = Temporalio::Bridge::Api::ActivityResult::ActivityExecutionResult.new(
          failed: Temporalio::Bridge::Api::ActivityResult::Failure.new(failure: failure),
        )

        complete_activity_task(task_token, result)
      end

      def complete_activity_task_with_cancellation(task_token, failure)
        result = Temporalio::Bridge::Api::ActivityResult::ActivityExecutionResult.new(
          cancelled: Temporalio::Bridge::Api::ActivityResult::Cancellation.new(failure: failure),
        )

        complete_activity_task(task_token, result)
      end

      def record_activity_heartbeat(task_token, payloads)
        proto = Temporalio::Bridge::Api::CoreInterface::ActivityHeartbeat.new(
          task_token: task_token,
          details: payloads,
        )
        encoded_proto = Temporalio::Bridge::Api::CoreInterface::ActivityHeartbeat.encode(proto)

        core_worker.record_activity_heartbeat(encoded_proto)
      end

      def poll_workflow_activation
        with_queue do |done|
          core_worker.poll_workflow_activation do |task, error|
            done.call(task && Temporalio::Bridge::Api::WorkflowActivation::WorkflowActivation.decode(task), error)
          end
        end
      end

      def complete_workflow_activation_with_success(run_id, commands)
        proto = Temporalio::Bridge::Api::WorkflowCompletion::WorkflowActivationCompletion.new(
          run_id: run_id,
          successful: Temporalio::Bridge::Api::WorkflowCompletion::Success.new(commands: commands),
        )

        complete_workflow_activation(proto)
      end

      def complete_workflow_activation_with_failure(run_id, failure)
        proto = Temporalio::Bridge::Api::WorkflowCompletion::WorkflowActivationCompletion.new(
          run_id: run_id,
          failed: Temporalio::Bridge::Api::WorkflowCompletion::Failure.new(failure: failure),
        )

        complete_workflow_activation(proto)
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
        proto = Temporalio::Bridge::Api::CoreInterface::ActivityTaskCompletion.new(
          task_token: task_token,
          result: result,
        )
        encoded_proto = Temporalio::Bridge::Api::CoreInterface::ActivityTaskCompletion.encode(proto)

        with_queue do |done|
          core_worker.complete_activity_task(encoded_proto, &done)
        end
      end

      def complete_workflow_activation(proto)
        encoded_proto = Temporalio::Bridge::Api::WorkflowCompletion::WorkflowActivationCompletion.encode(proto)

        with_queue do |done|
          core_worker.complete_workflow_activation(encoded_proto, &done)
        end
      end
    end
  end
end
