# frozen_string_literal: true

require 'temporalio/cancellation'
require 'temporalio/workflow'
require 'temporalio/workflow/child_workflow_handle'

module Temporalio
  module Internal
    module Worker
      class WorkflowInstance
        # Implementation of the child workflow handle.
        class ChildWorkflowHandle < Workflow::ChildWorkflowHandle
          attr_reader :id, :first_execution_run_id

          def initialize(id:, first_execution_run_id:, instance:, cancellation:, cancel_callback_key:) # rubocop:disable Lint/MissingSuper
            @id = id
            @first_execution_run_id = first_execution_run_id
            @instance = instance
            @cancellation = cancellation
            @cancel_callback_key = cancel_callback_key
            @resolution = nil
          end

          def result
            # Notice that we actually provide a detached cancellation here instead of defaulting to workflow
            # cancellation because we don't want workflow cancellation (or a user-provided cancellation to this result
            # call) to be able to interrupt waiting on a child that may be processing the cancellation.
            Workflow.wait_condition(cancellation: Cancellation.new) { @resolution }

            case @resolution.status
            when :completed
              @instance.payload_converter.from_payload(@resolution.completed.result)
            when :failed
              raise @instance.failure_converter.from_failure(@resolution.failed.failure, @instance.payload_converter)
            when :cancelled
              raise @instance.failure_converter.from_failure(@resolution.cancelled.failure, @instance.payload_converter)
            else
              raise "Unrecognized resolution status: #{@resolution.status}"
            end
          end

          def _resolve(resolution)
            @cancellation.remove_cancel_callback(@cancel_callback_key)
            @resolution = resolution
          end

          def signal(signal, *args, cancellation: Workflow.cancellation)
            @instance.context._signal_child_workflow(id:, signal:, args:, cancellation:)
          end
        end
      end
    end
  end
end
