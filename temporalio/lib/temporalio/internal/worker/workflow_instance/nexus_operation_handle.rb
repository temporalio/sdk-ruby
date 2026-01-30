# frozen_string_literal: true

require 'temporalio/cancellation'
require 'temporalio/workflow'
require 'temporalio/workflow/nexus_operation_handle'

module Temporalio
  module Internal
    module Worker
      class WorkflowInstance
        # Implementation of the Nexus operation handle.
        class NexusOperationHandle < Workflow::NexusOperationHandle
          attr_reader :operation_token, :result_hint

          def initialize(operation_token:, instance:, cancellation:, cancel_callback_key:, # rubocop:disable Lint/MissingSuper
                         result_hint:)
            @operation_token = operation_token
            @instance = instance
            @cancellation = cancellation
            @cancel_callback_key = cancel_callback_key
            @result_hint = result_hint
            @resolution = nil
          end

          def result(result_hint: nil)
            # Use detached cancellation like child workflow to avoid interrupting result wait
            Workflow.wait_condition(cancellation: Cancellation.new) { @resolution }

            case @resolution.status
            when :completed
              @instance.payload_converter.from_payload(@resolution.completed, hint: result_hint || @result_hint)
            when :failed
              raise @instance.failure_converter.from_failure(@resolution.failed, @instance.payload_converter)
            when :cancelled
              raise @instance.failure_converter.from_failure(@resolution.cancelled, @instance.payload_converter)
            when :timed_out
              raise @instance.failure_converter.from_failure(@resolution.timed_out, @instance.payload_converter)
            else
              raise "Unrecognized Nexus operation result status: #{@resolution.status}"
            end
          end

          def _resolve(resolution)
            @cancellation.remove_cancel_callback(@cancel_callback_key)
            @resolution = resolution
          end
        end
      end
    end
  end
end
