require 'temporal/api/failure/v1/message_pb'
require 'temporal/error/failure'
require 'temporal/failure_converter/base'
require 'temporal/payload_converter'

module Temporal
  module FailureConverter
    class Basic
      def initialize(payload_converter: Temporal::PayloadConverter::DEFAULT)
        @payload_converter = payload_converter
      end

      def to_failure(error)
        Temporal::Api::Failure::V1::Failure.new(message: error.message)

        # case error
        # when Temporal::Error::TimeoutError
        #   to_timeout_failure(error)

        # if (this.options.encodeCommonAttributes) {
        #   const { message, stackTrace } = failure;
        #   failure.message = 'Encoded failure';
        #   failure.stackTrace = '';
        #   failure.encodedAttributes = this.options.payloadConverter.toPayload({ message, stack_trace: stackTrace });
        # }
      end

      def from_failure(failure)
        # TODO: decode encoded attributes

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

      def from_payloads(payloads)
        return unless payloads

        # TODO: depend on the DataConverter instead?
        payloads.payloads.map { |payload| payload_converter.from_payload(payload) }
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
          # TODO: Convert to an enum class
          failure.timeout_failure_info.timeout_type,
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
          # TODO: Convert to an enum class
          failure.activity_failure_info.retry_state,
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
          # TODO: Convert to an enum class
          failure.child_workflow_execution_failure_info.retry_state,
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
