# frozen_string_literal: true

require 'logger'
require 'temporalio/converters'
require 'temporalio/internal/bridge/api'
require 'temporalio/internal/worker/workflow_instance'
require 'temporalio/runtime'
require 'temporalio/workflow'
require 'test'

module Worker
  class WorkflowInstanceTest < Test
    class ContinueAsNewSuggestionWorkflow < Temporalio::Workflow::Definition
      def execute
        [
          Temporalio::Workflow.continue_as_new_suggested,
          Temporalio::Workflow.suggest_continue_as_new_reasons
        ]
      end
    end

    def test_continue_as_new_suggestion_reasons_are_visible_as_workflow_enum_ints
      data_converter = Temporalio::Converters::DataConverter.default
      initial_activation = Temporalio::Internal::Bridge::Api::WorkflowActivation::WorkflowActivation.new(
        run_id: 'run-id',
        timestamp: Google::Protobuf::Timestamp.new(seconds: Time.now.to_i),
        history_length: 1,
        history_size_bytes: 1,
        jobs: [
          Temporalio::Internal::Bridge::Api::WorkflowActivation::WorkflowActivationJob.new(
            initialize_workflow: Temporalio::Internal::Bridge::Api::WorkflowActivation::InitializeWorkflow.new(
              workflow_type: 'ContinueAsNewSuggestionWorkflow',
              workflow_id: 'workflow-id',
              randomness_seed: 1,
              start_time: Google::Protobuf::Timestamp.new(seconds: Time.now.to_i),
              workflow_task_timeout: Google::Protobuf::Duration.new(seconds: 10)
            )
          )
        ]
      )

      instance = Temporalio::Internal::Worker::WorkflowInstance.new(
        Temporalio::Internal::Worker::WorkflowInstance::Details.new(
          namespace: 'namespace',
          task_queue: 'task-queue',
          definition: Temporalio::Workflow::Definition::Info.from_class(ContinueAsNewSuggestionWorkflow),
          initial_activation:,
          logger: Logger.new(nil),
          metric_meter: Temporalio::Runtime.default.metric_meter,
          payload_converter: data_converter.payload_converter,
          failure_converter: data_converter.failure_converter,
          interceptors: [],
          disable_eager_activity_execution: false,
          illegal_calls: Temporalio::Internal::Worker::WorkflowInstance::IllegalCallTracer.frozen_validated_illegal_calls({}),
          workflow_failure_exception_types: [],
          unsafe_workflow_io_enabled: false,
          assert_valid_local_activity: ->(_) {}
        )
      )

      completion = instance.activate(
        Temporalio::Internal::Bridge::Api::WorkflowActivation::WorkflowActivation.new(
          run_id: 'run-id',
          timestamp: Google::Protobuf::Timestamp.new(seconds: Time.now.to_i),
          history_length: 1,
          history_size_bytes: 1,
          continue_as_new_suggested: true,
          suggest_continue_as_new_reasons: [
            Temporalio::Api::Enums::V1::SuggestContinueAsNewReason::
              SUGGEST_CONTINUE_AS_NEW_REASON_HISTORY_SIZE_TOO_LARGE,
            Temporalio::Api::Enums::V1::SuggestContinueAsNewReason::
              SUGGEST_CONTINUE_AS_NEW_REASON_TOO_MANY_HISTORY_EVENTS
          ]
        )
      )
      command = completion.successful.commands.fetch(0)
      result = data_converter.payload_converter.from_payload(command.complete_workflow_execution.result)

      assert_equal [
        true,
        [
          Temporalio::SuggestContinueAsNewReason::HISTORY_SIZE_TOO_LARGE,
          Temporalio::SuggestContinueAsNewReason::TOO_MANY_HISTORY_EVENTS
        ]
      ], result
    end
  end
end
