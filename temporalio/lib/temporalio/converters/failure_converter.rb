# frozen_string_literal: true

require 'temporalio/api'
require 'temporalio/error'
require 'temporalio/internal/proto_utils'

module Temporalio
  module Converters
    # Base class for converting Ruby errors to/from Temporal failures.
    class FailureConverter
      # @return [FailureConverter] Default failure converter.
      def self.default
        @default ||= Ractor.make_shareable(FailureConverter.new)
      end

      # @return [Boolean] If +true+, the message and stack trace of the failure will be moved into the encoded attribute
      #   section of the failure which can be encoded with a codec.
      attr_reader :encode_common_attributes

      # Create failure converter.
      #
      # @param encode_common_attributes [Boolean] If +true+, the message and stack trace of the failure will be moved
      #   into the encoded attribute section of the failure which can be encoded with a codec.
      def initialize(encode_common_attributes: false)
        @encode_common_attributes = encode_common_attributes
      end

      # Convert a Ruby error to a Temporal failure.
      #
      # @param error [Exception] Ruby error.
      # @param converter [DataConverter, PayloadConverter] Converter for payloads.
      # @return [Api::Failure::V1::Failure] Converted failure.
      def to_failure(error, converter)
        failure = Api::Failure::V1::Failure.new(
          message: error.message,
          stack_trace: error.backtrace&.join("\n")
        )
        cause = error.cause
        failure.cause = to_failure(cause, converter) if cause

        # Convert specific error type details
        case error
        when Error::ApplicationError
          failure.application_failure_info = Api::Failure::V1::ApplicationFailureInfo.new(
            type: error.type,
            non_retryable: error.non_retryable,
            details: converter.to_payloads(error.details),
            next_retry_delay: Internal::ProtoUtils.seconds_to_duration(error.next_retry_delay)
          )
        when Error::TimeoutError
          failure.timeout_failure_info = Api::Failure::V1::TimeoutFailureInfo.new(
            timeout_type: error.type,
            last_heartbeat_details: converter.to_payloads(error.last_heartbeat_details)
          )
        when Error::CanceledError
          failure.canceled_failure_info = Api::Failure::V1::CanceledFailureInfo.new(
            details: converter.to_payloads(error.details)
          )
        when Error::TerminatedError
          failure.terminated_failure_info = Api::Failure::V1::TerminatedFailureInfo.new
        when Error::ServerError
          failure.server_failure_info = Api::Failure::V1::ServerFailureInfo.new(
            non_retryable: error.non_retryable
          )
        when Error::ActivityError
          failure.activity_failure_info = Api::Failure::V1::ActivityFailureInfo.new(
            scheduled_event_id: error.scheduled_event_id,
            started_event_id: error.started_event_id,
            identity: error.identity,
            activity_type: Api::Common::V1::ActivityType.new(name: error.activity_type),
            activity_id: error.activity_id,
            retry_state: error.retry_state
          )
        when Error::ChildWorkflowError
          failure.child_workflow_execution_failure_info = Api::Failure::V1::ChildWorkflowExecutionFailureInfo.new(
            namespace: error.namespace,
            workflow_execution: Api::Common::V1::WorkflowExecution.new(
              workflow_id: error.workflow_id,
              run_id: error.run_id
            ),
            workflow_type: Api::Common::V1::WorkflowType.new(name: error.workflow_type),
            initiated_event_id: error.initiated_event_id,
            started_event_id: error.started_event_id,
            retry_state: error.retry_state
          )
        else
          failure.application_failure_info = Api::Failure::V1::ApplicationFailureInfo.new(
            type: error.class.name.split('::').last
          )
        end

        # If encoding common attributes, move message and stack trace
        if @encode_common_attributes
          failure.encoded_attributes = converter.to_payload(
            { message: failure.message, stack_trace: failure.stack_trace }
          )
          failure.message = 'Encoded failure'
          failure.stack_trace = ''
        end

        failure
      end

      # Convert a Temporal failure to a Ruby error.
      #
      # @param failure [Api::Failure::V1::Failure] Failure.
      # @param converter [DataConverter, PayloadConverter] Converter for payloads.
      # @return [Error::Failure] Converted Ruby error.
      def from_failure(failure, converter)
        # If encoded attributes have any of the fields we expect, try to decode
        # but ignore any error
        unless failure.encoded_attributes.nil?
          begin
            attrs = converter.from_payload(failure.encoded_attributes)
            if attrs.is_a?(Hash)
              # Shallow dup failure here to avoid affecting caller
              failure = failure.dup
              failure.message = attrs['message'] if attrs.key?('message')
              failure.stack_trace = attrs['stack_trace'] if attrs.key?('stack_trace')
            end
          rescue StandardError
            # Ignore failures
          end
        end

        # Convert
        error = if failure.application_failure_info
                  Error::ApplicationError.new(
                    Internal::ProtoUtils.string_or(failure.message, 'Application error'),
                    *converter.from_payloads(failure.application_failure_info.details),
                    type: Internal::ProtoUtils.string_or(failure.application_failure_info.type),
                    non_retryable: failure.application_failure_info.non_retryable,
                    next_retry_delay: failure.application_failure_info.next_retry_delay&.to_f
                  )
                elsif failure.timeout_failure_info
                  Error::TimeoutError.new(
                    Internal::ProtoUtils.string_or(failure.message, 'Timeout'),
                    type: Internal::ProtoUtils.enum_to_int(Api::Enums::V1::TimeoutType,
                                                           failure.timeout_failure_info.timeout_type),
                    last_heartbeat_details: converter.from_payloads(
                      failure.timeout_failure_info.last_heartbeat_details
                    )
                  )
                elsif failure.canceled_failure_info
                  Error::CanceledError.new(
                    Internal::ProtoUtils.string_or(failure.message, 'Canceled'),
                    details: converter.from_payloads(failure.canceled_failure_info.details)
                  )
                elsif failure.terminated_failure_info
                  Error::TerminatedError.new(
                    Internal::ProtoUtils.string_or(failure.message, 'Terminated'),
                    details: []
                  )
                elsif failure.server_failure_info
                  Error::ServerError.new(
                    Internal::ProtoUtils.string_or(failure.message, 'Server error'),
                    non_retryable: failure.server_failure_info.non_retryable
                  )
                elsif failure.activity_failure_info
                  Error::ActivityError.new(
                    Internal::ProtoUtils.string_or(failure.message, 'Activity error'),
                    scheduled_event_id: failure.activity_failure_info.scheduled_event_id,
                    started_event_id: failure.activity_failure_info.started_event_id,
                    identity: failure.activity_failure_info.identity,
                    activity_type: failure.activity_failure_info.activity_type.name,
                    activity_id: failure.activity_failure_info.activity_id,
                    retry_state: Internal::ProtoUtils.enum_to_int(
                      Api::Enums::V1::RetryState,
                      failure.activity_failure_info.retry_state,
                      zero_means_nil: true
                    )
                  )
                elsif failure.child_workflow_execution_failure_info
                  Error::ChildWorkflowError.new(
                    Internal::ProtoUtils.string_or(failure.message, 'Child workflow error'),
                    namespace: failure.child_workflow_execution_failure_info.namespace,
                    workflow_id: failure.child_workflow_execution_failure_info.workflow_execution.workflow_id,
                    run_id: failure.child_workflow_execution_failure_info.workflow_execution.run_id,
                    workflow_type: failure.child_workflow_execution_failure_info.workflow_type.name,
                    initiated_event_id: failure.child_workflow_execution_failure_info.initiated_event_id,
                    started_event_id: failure.child_workflow_execution_failure_info.started_event_id,
                    retry_state: Internal::ProtoUtils.enum_to_int(
                      Api::Enums::V1::RetryState,
                      failure.child_workflow_execution_failure_info.retry_state,
                      zero_means_nil: true
                    )
                  )
                else
                  Error::Failure.new(Internal::ProtoUtils.string_or(failure.message, 'Failure error'))
                end

        Error._with_backtrace_and_cause(
          error,
          backtrace: failure.stack_trace.split("\n"),
          cause: failure.cause ? from_failure(failure.cause, converter) : nil
        )
      end
    end
  end
end
