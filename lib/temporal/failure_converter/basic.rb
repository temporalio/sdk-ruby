require 'temporal/api/common/v1/message_pb'
require 'temporal/api/failure/v1/message_pb'
require 'temporal/error/failure'
require 'temporal/failure_converter/base'
require 'temporal/payload_converter'
require 'temporal/retry_state'
require 'temporal/timeout_type'

module Temporal
  module FailureConverter
    class Basic
      def initialize(
        payload_converter: Temporal::PayloadConverter::DEFAULT,
        encode_common_attributes: false
      )
        @payload_converter = payload_converter
        @encode_common_attributes = encode_common_attributes
      end

      def to_failure(error)
        return error.raw if error.is_a?(Temporal::Error::Failure) && error.raw

        failure =
          case error
          when Temporal::Error::ApplicationError
            to_application_failure(error)
          when Temporal::Error::TimeoutError
            to_timeout_failure(error)
          when Temporal::Error::CancelledError
            to_cancelled_failure(error)
          when Temporal::Error::TerminatedError
            to_terminated_failure(error)
          when Temporal::Error::ServerError
            to_server_failure(error)
          when Temporal::Error::ResetWorkflowError
            to_reset_workflow_failure(error)
          when Temporal::Error::ActivityError
            to_activity_failure(error)
          when Temporal::Error::ChildWorkflowError
            to_child_workflow_execution_failure(error)
          else
            to_generic_failure(error)
          end

        failure.message = error.message
        failure.stack_trace = error.backtrace&.join("\n") unless error.backtrace&.empty?
        failure.cause = to_failure(error.cause) if error.cause

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

      def from_failure(failure)
        failure = apply_from_encoded_attributes(failure)
        cause = failure.cause ? from_failure(failure.cause) : nil

        error =
          if failure.application_failure_info
            from_application_failure(failure, cause)
          elsif failure.timeout_failure_info
            from_timeout_failure(failure, cause)
          elsif failure.canceled_failure_info
            from_cancelled_failure(failure, cause)
          elsif failure.terminated_failure_info
            from_terminated_failure(failure, cause)
          elsif failure.server_failure_info
            from_server_failure(failure, cause)
          elsif failure.reset_workflow_failure_info
            from_reset_workflow_failure(failure, cause)
          elsif failure.activity_failure_info
            from_activity_failure(failure, cause)
          elsif failure.child_workflow_execution_failure_info
            from_child_workflow_execution_failure(failure, cause)
          else
            from_generic_failure(failure, cause)
          end

        unless failure.stack_trace.empty?
          error.set_backtrace(failure.stack_trace.split("\n"))
        end

        error
      end

      private

      attr_reader :payload_converter

      def encode_common_attributes?
        @encode_common_attributes
      end

      def to_payloads(data)
        return if data.nil? || Array(data).empty?

        payloads = Array(data).map { |value| payload_converter.to_payload(value) }
        Temporal::Api::Common::V1::Payloads.new(payloads: payloads)
      end

      def from_payloads(payloads)
        return unless payloads

        payloads.payloads.map { |payload| payload_converter.from_payload(payload) }
      end

      def apply_from_encoded_attributes(failure)
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

      def to_application_failure(error)
        Temporal::Api::Failure::V1::Failure.new(
          application_failure_info: {
            type: error.type,
            non_retryable: error.non_retryable,
            details: to_payloads(error.details),
          },
        )
      end

      def to_timeout_failure(error)
        Temporal::Api::Failure::V1::Failure.new(
          timeout_failure_info: {
            timeout_type: Temporal::TimeoutType.to_raw(error.type),
            last_heartbeat_details: to_payloads(error.last_heartbeat_details),
          },
        )
      end

      def to_cancelled_failure(error)
        Temporal::Api::Failure::V1::Failure.new(
          canceled_failure_info: {
            details: to_payloads(error.details),
          },
        )
      end

      def to_terminated_failure(error)
        Temporal::Api::Failure::V1::Failure.new(
          terminated_failure_info: { },
        )
      end

      def to_server_failure(error)
        Temporal::Api::Failure::V1::Failure.new(
          server_failure_info: {
            non_retryable: error.non_retryable,
          },
        )
      end

      def to_reset_workflow_failure(error)
        Temporal::Api::Failure::V1::Failure.new(
          reset_workflow_failure_info: {
            last_heartbeat_details: to_payloads(error.last_heartbeat_details),
          },
        )
      end

      def to_activity_failure(error)
        Temporal::Api::Failure::V1::Failure.new(
          activity_failure_info: {
            scheduled_event_id: error.scheduled_event_id,
            started_event_id: error.started_event_id,
            identity: error.identity,
            activity_type: { name: error.activity_name },
            activity_id: error.activity_id,
            retry_state: Temporal::RetryState.to_raw(error.retry_state),
          },
        )
      end

      def to_child_workflow_execution_failure(error)
        Temporal::Api::Failure::V1::Failure.new(
          child_workflow_execution_failure_info: {
            namespace: error.namespace,
            workflow_execution: { workflow_id: error.workflow_id, run_id: error.run_id },
            workflow_type: { name: error.workflow_name },
            initiated_event_id: error.initiated_event_id,
            started_event_id: error.started_event_id,
            retry_state: Temporal::RetryState.to_raw(error.retry_state),
          },
        )
      end

      def to_generic_failure(error)
        Temporal::Api::Failure::V1::Failure.new(
          application_failure_info: {
            type: error.class.name,
          },
        )
      end

      def from_application_failure(failure, cause)
        Temporal::Error::ApplicationError.new(
          failure.message || 'Application error',
          failure.application_failure_info.type,
          from_payloads(failure.application_failure_info.details),
          failure.application_failure_info.non_retryable,
          failure,
          cause,
        )
      end

      def from_timeout_failure(failure, cause)
        Temporal::Error::TimeoutError.new(
          failure.message || 'Timeout',
          Temporal::TimeoutType.from_raw(failure.timeout_failure_info.timeout_type),
          from_payloads(failure.timeout_failure_info.last_heartbeat_details),
          failure,
          cause,
        )
      end

      def from_cancelled_failure(failure, cause)
        Temporal::Error::CancelledError.new(
          failure.message || 'Cancelled',
          from_payloads(failure.canceled_failure_info.details),
          failure,
          cause,
        )
      end

      def from_terminated_failure(failure, cause)
        Temporal::Error::TerminatedError.new(
          failure.message || 'Terminated',
          failure,
          cause,
        )
      end

      def from_server_failure(failure, cause)
        Temporal::Error::ServerError.new(
          failure.message || 'Server error',
          failure.server_failure_info.non_retryable,
          failure,
          cause,
        )
      end

      def from_reset_workflow_failure(failure, cause)
        Temporal::Error::ResetWorkflowError.new(
          failure.message || 'Reset workflow error',
          from_payloads(failure.reset_workflow_failure_info.last_heartbeat_details),
          failure,
          cause,
        )
      end

      def from_activity_failure(failure, cause)
        Temporal::Error::ActivityError.new(
          failure.message || 'Activity error',
          failure.activity_failure_info.scheduled_event_id,
          failure.activity_failure_info.started_event_id,
          failure.activity_failure_info.identity,
          failure.activity_failure_info.activity_type.name,
          failure.activity_failure_info.activity_id,
          Temporal::RetryState.from_raw(failure.activity_failure_info.retry_state),
          failure,
          cause,
        )
      end

      def from_child_workflow_execution_failure(failure, cause)
        Temporal::Error::ChildWorkflowError.new(
          failure.message || 'Child workflow error',
          failure.child_workflow_execution_failure_info.namespace,
          failure.child_workflow_execution_failure_info.workflow_execution.workflow_id,
          failure.child_workflow_execution_failure_info.workflow_execution.run_id,
          failure.child_workflow_execution_failure_info.workflow_type.name,
          failure.child_workflow_execution_failure_info.initiated_event_id,
          failure.child_workflow_execution_failure_info.started_event_id,
          Temporal::RetryState.from_raw(failure.child_workflow_execution_failure_info.retry_state),
          failure,
          cause,
        )
      end

      def from_generic_failure(failure, cause)
        Temporal::Error::Failure.new(
          failure.message || 'Failure error',
          failure,
          cause,
        )
      end
    end
  end
end
