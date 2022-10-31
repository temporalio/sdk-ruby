require 'temporal/api/common/v1/message_pb'
require 'temporal/api/failure/v1/message_pb'
require 'temporal/error/failure'
require 'temporal/failure_converter/base'
require 'temporal/retry_state'
require 'temporal/timeout_type'

module Temporal
  module FailureConverter
    class Basic < Base
      def initialize(encode_common_attributes: false)
        super()

        @encode_common_attributes = encode_common_attributes
      end

      def to_failure(error, payload_converter)
        return error.raw if error.is_a?(Temporal::Error::Failure) && error.raw

        failure =
          case error
          when Temporal::Error::ApplicationError
            to_application_failure(error, payload_converter)
          when Temporal::Error::TimeoutError
            to_timeout_failure(error, payload_converter)
          when Temporal::Error::CancelledError
            to_cancelled_failure(error, payload_converter)
          when Temporal::Error::TerminatedError
            to_terminated_failure(error, payload_converter)
          when Temporal::Error::ServerError
            to_server_failure(error, payload_converter)
          when Temporal::Error::ResetWorkflowError
            to_reset_workflow_failure(error, payload_converter)
          when Temporal::Error::ActivityError
            to_activity_failure(error, payload_converter)
          when Temporal::Error::ChildWorkflowError
            to_child_workflow_execution_failure(error, payload_converter)
          else
            to_generic_failure(error, payload_converter)
          end

        failure.message = error.message
        failure.stack_trace = error.backtrace&.join("\n") || ''
        failure.cause = to_failure(error.cause, payload_converter) if error.cause

        if encode_common_attributes?
          failure.encoded_attributes = payload_converter.to_payload(
            'message' => failure.message,
            'stack_trace' => failure.stack_trace,
          )
          failure.message = 'Encoded failure'
          failure.stack_trace = ''
        end

        failure
      end

      def from_failure(failure, payload_converter)
        failure = apply_from_encoded_attributes(failure, payload_converter)
        cause = failure.cause ? from_failure(failure.cause, payload_converter) : nil

        error =
          if failure.application_failure_info
            from_application_failure(failure, failure.application_failure_info, cause, payload_converter)
          elsif failure.timeout_failure_info
            from_timeout_failure(failure, failure.timeout_failure_info, cause, payload_converter)
          elsif failure.canceled_failure_info
            from_cancelled_failure(failure, failure.canceled_failure_info, cause, payload_converter)
          elsif failure.terminated_failure_info
            from_terminated_failure(failure, failure.terminated_failure_info, cause, payload_converter)
          elsif failure.server_failure_info
            from_server_failure(failure, failure.server_failure_info, cause, payload_converter)
          elsif failure.reset_workflow_failure_info
            from_reset_workflow_failure(failure, failure.reset_workflow_failure_info, cause, payload_converter)
          elsif failure.activity_failure_info
            from_activity_failure(failure, failure.activity_failure_info, cause, payload_converter)
          elsif failure.child_workflow_execution_failure_info
            from_child_workflow_execution_failure(
              failure,
              failure.child_workflow_execution_failure_info,
              cause,
              payload_converter,
            )
          else
            from_generic_failure(failure, cause, payload_converter)
          end

        unless failure.stack_trace.empty?
          error.set_backtrace(failure.stack_trace.split("\n"))
        end

        error
      end

      private

      def encode_common_attributes?
        @encode_common_attributes
      end

      def to_payloads(data, payload_converter)
        return if data.nil? || Array(data).empty?

        payloads = Array(data).map { |value| payload_converter.to_payload(value) }
        Temporal::Api::Common::V1::Payloads.new(payloads: payloads)
      end

      def from_payloads(payloads, payload_converter)
        return [] unless payloads

        payloads.payloads.map { |payload| payload_converter.from_payload(payload) }
      end

      def apply_from_encoded_attributes(failure, payload_converter)
        return failure unless failure.encoded_attributes

        attributes = payload_converter.from_payload(failure.encoded_attributes)
        return failure unless attributes.is_a?(Hash)

        failure = failure.dup
        if attributes['message'].is_a?(String)
          failure.message = attributes['message']
        end

        if attributes['stack_trace'].is_a?(String)
          failure.stack_trace = attributes['stack_trace']
        end

        failure
      end

      def to_application_failure(error, payload_converter)
        Temporal::Api::Failure::V1::Failure.new(
          application_failure_info: Temporal::Api::Failure::V1::ApplicationFailureInfo.new(
            type: error.type,
            non_retryable: error.non_retryable,
            details: to_payloads(error.details, payload_converter),
          ),
        )
      end

      def to_timeout_failure(error, payload_converter)
        Temporal::Api::Failure::V1::Failure.new(
          timeout_failure_info: Temporal::Api::Failure::V1::TimeoutFailureInfo.new(
            timeout_type: Temporal::TimeoutType.to_raw(error.type),
            last_heartbeat_details: to_payloads(error.last_heartbeat_details, payload_converter),
          ),
        )
      end

      def to_cancelled_failure(error, payload_converter)
        Temporal::Api::Failure::V1::Failure.new(
          canceled_failure_info: Temporal::Api::Failure::V1::CanceledFailureInfo.new(
            details: to_payloads(error.details, payload_converter),
          ),
        )
      end

      def to_terminated_failure(_error, _payload_converter)
        Temporal::Api::Failure::V1::Failure.new(
          terminated_failure_info: Temporal::Api::Failure::V1::TerminatedFailureInfo.new,
        )
      end

      def to_server_failure(error, _payload_converter)
        Temporal::Api::Failure::V1::Failure.new(
          server_failure_info: Temporal::Api::Failure::V1::ServerFailureInfo.new(
            non_retryable: error.non_retryable,
          ),
        )
      end

      def to_reset_workflow_failure(error, payload_converter)
        Temporal::Api::Failure::V1::Failure.new(
          reset_workflow_failure_info: Temporal::Api::Failure::V1::ResetWorkflowFailureInfo.new(
            last_heartbeat_details: to_payloads(error.last_heartbeat_details, payload_converter),
          ),
        )
      end

      def to_activity_failure(error, _payload_converter)
        Temporal::Api::Failure::V1::Failure.new(
          activity_failure_info: Temporal::Api::Failure::V1::ActivityFailureInfo.new(
            scheduled_event_id: error.scheduled_event_id,
            started_event_id: error.started_event_id,
            identity: error.identity,
            activity_type: Temporal::Api::Common::V1::ActivityType.new(name: error.activity_name || ''),
            activity_id: error.activity_id,
            retry_state: Temporal::RetryState.to_raw(error.retry_state),
          ),
        )
      end

      def to_child_workflow_execution_failure(error, _payload_converter)
        Temporal::Api::Failure::V1::Failure.new(
          child_workflow_execution_failure_info:
            Temporal::Api::Failure::V1::ChildWorkflowExecutionFailureInfo.new(
              namespace: error.namespace,
              workflow_execution: Temporal::Api::Common::V1::WorkflowExecution.new(
                workflow_id: error.workflow_id || '',
                run_id: error.run_id || '',
              ),
              workflow_type: Temporal::Api::Common::V1::WorkflowType.new(name: error.workflow_name || ''),
              initiated_event_id: error.initiated_event_id,
              started_event_id: error.started_event_id,
              retry_state: Temporal::RetryState.to_raw(error.retry_state),
            ),
        )
      end

      def to_generic_failure(error, _payload_converter)
        Temporal::Api::Failure::V1::Failure.new(
          application_failure_info: Temporal::Api::Failure::V1::ApplicationFailureInfo.new(
            type: error.class.name,
          ),
        )
      end

      def from_application_failure(failure, failure_info, cause, payload_converter)
        Temporal::Error::ApplicationError.new(
          failure.message || 'Application error',
          type: failure_info.type,
          details: from_payloads(failure_info.details, payload_converter),
          non_retryable: failure_info.non_retryable,
          raw: failure,
          cause: cause,
        )
      end

      def from_timeout_failure(failure, failure_info, cause, payload_converter)
        Temporal::Error::TimeoutError.new(
          failure.message || 'Timeout',
          type: Temporal::TimeoutType.from_raw(failure_info.timeout_type),
          last_heartbeat_details: from_payloads(failure_info.last_heartbeat_details, payload_converter),
          raw: failure,
          cause: cause,
        )
      end

      def from_cancelled_failure(failure, failure_info, cause, payload_converter)
        Temporal::Error::CancelledError.new(
          failure.message || 'Cancelled',
          details: from_payloads(failure_info.details, payload_converter),
          raw: failure,
          cause: cause,
        )
      end

      def from_terminated_failure(failure, _failure_info, cause, _payload_converter)
        Temporal::Error::TerminatedError.new(
          failure.message || 'Terminated',
          raw: failure,
          cause: cause,
        )
      end

      def from_server_failure(failure, failure_info, cause, _payload_converter)
        Temporal::Error::ServerError.new(
          failure.message || 'Server error',
          non_retryable: failure_info.non_retryable,
          raw: failure,
          cause: cause,
        )
      end

      def from_reset_workflow_failure(failure, failure_info, cause, payload_converter)
        Temporal::Error::ResetWorkflowError.new(
          failure.message || 'Reset workflow error',
          last_heartbeat_details: from_payloads(failure_info.last_heartbeat_details, payload_converter),
          raw: failure,
          cause: cause,
        )
      end

      def from_activity_failure(failure, failure_info, cause, _payload_converter)
        Temporal::Error::ActivityError.new(
          failure.message || 'Activity error',
          scheduled_event_id: failure_info.scheduled_event_id,
          started_event_id: failure_info.started_event_id,
          identity: failure_info.identity,
          activity_name: failure_info.activity_type&.name,
          activity_id: failure_info.activity_id,
          retry_state: Temporal::RetryState.from_raw(failure_info.retry_state),
          raw: failure,
          cause: cause,
        )
      end

      def from_child_workflow_execution_failure(failure, failure_info, cause, _payload_converter)
        Temporal::Error::ChildWorkflowError.new(
          failure.message || 'Child workflow error',
          namespace: failure_info.namespace,
          workflow_id: failure_info.workflow_execution&.workflow_id,
          run_id: failure_info.workflow_execution&.run_id,
          workflow_name: failure_info.workflow_type&.name,
          initiated_event_id: failure_info.initiated_event_id,
          started_event_id: failure_info.started_event_id,
          retry_state: Temporal::RetryState.from_raw(failure_info.retry_state),
          raw: failure,
          cause: cause,
        )
      end

      def from_generic_failure(failure, cause, _payload_converter)
        Temporal::Error::Failure.new(
          failure.message || 'Failure error',
          raw: failure,
          cause: cause,
        )
      end
    end
  end
end
