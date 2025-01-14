# frozen_string_literal: true

require 'temporalio/api'
require 'temporalio/converters/failure_converter'
require 'temporalio/testing'
require 'test'

module Converters
  class FailureConverterTest < Test
    def test_failure_with_causes
      # Make multiple nested errors
      orig_err = assert_raises do
        begin
          begin
            raise 'Unset error class'
          rescue StandardError
            raise Temporalio::Error::ApplicationError, 'Application error no details'
          end
        rescue StandardError
          raise Temporalio::Error::ApplicationError.new('Application error with details', { foo: 'bar' })
        end
      rescue StandardError
        raise Temporalio::Error::ChildWorkflowError.new(
          'Child error',
          namespace: 'ns',
          workflow_id: 'wfid',
          run_id: 'runid',
          workflow_type: 'wftype',
          initiated_event_id: 123,
          started_event_id: 456,
          retry_state: Temporalio::Error::RetryState::RETRY_POLICY_NOT_SET
        )
      end

      # Confirm multiple nested
      assert_instance_of Temporalio::Error::ChildWorkflowError, orig_err
      refute_empty orig_err.backtrace
      assert_equal 'Child error', orig_err.message
      assert_equal Temporalio::Error::RetryState::RETRY_POLICY_NOT_SET, orig_err.retry_state
      assert_instance_of Temporalio::Error::ApplicationError, orig_err.cause
      refute_empty orig_err.cause.backtrace
      assert_equal 'Application error with details', orig_err.cause.message
      assert_equal [{ foo: 'bar' }], orig_err.cause.details
      assert_nil orig_err.cause.type
      assert_instance_of Temporalio::Error::ApplicationError, orig_err.cause.cause
      assert_equal 'Application error no details', orig_err.cause.cause.message
      assert_empty orig_err.cause.cause.details
      assert_instance_of RuntimeError, orig_err.cause.cause.cause
      assert_equal 'Unset error class', orig_err.cause.cause.cause.message

      # Confirm serialized as expected
      failure = Temporalio::Converters::DataConverter.default.to_failure(orig_err)
      assert_equal 'Child error', failure.message
      refute_empty failure.stack_trace
      assert_equal 'wfid', failure.child_workflow_execution_failure_info.workflow_execution.workflow_id
      assert_equal Temporalio::Error::RetryState::RETRY_POLICY_NOT_SET,
                   Temporalio::Internal::ProtoUtils.enum_to_int(
                     Temporalio::Api::Enums::V1::RetryState,
                     failure.child_workflow_execution_failure_info.retry_state
                   )
      assert_equal 'Application error with details', failure.cause.message
      assert_empty failure.cause.application_failure_info.type
      refute_nil failure.cause.application_failure_info.details
      assert_equal 'Application error no details', failure.cause.cause.message
      assert_empty failure.cause.cause.application_failure_info.details.payloads
      assert_equal 'Unset error class', failure.cause.cause.cause.message
      assert_equal 'RuntimeError', failure.cause.cause.cause.application_failure_info.type

      # Confirm deserialized as expected
      new_err = Temporalio::Converters::DataConverter.default.from_failure(failure) #: untyped
      assert_instance_of Temporalio::Error::ChildWorkflowError, new_err
      assert_equal orig_err.backtrace, new_err.backtrace
      assert_equal 'Child error', new_err.message
      assert_equal Temporalio::Error::RetryState::RETRY_POLICY_NOT_SET, new_err.retry_state
      assert_instance_of Temporalio::Error::ApplicationError, new_err.cause
      assert_equal orig_err.cause.backtrace, new_err.cause.backtrace
      assert_equal 'Application error with details', new_err.cause.message
      assert_equal [{ 'foo' => 'bar' }], new_err.cause.details
      assert_nil new_err.cause.type
      assert_instance_of Temporalio::Error::ApplicationError, new_err.cause.cause
      assert_equal orig_err.cause.cause.backtrace, new_err.cause.cause.backtrace
      assert_equal 'Application error no details', new_err.cause.cause.message
      assert_empty new_err.cause.cause.details
      assert_instance_of Temporalio::Error::ApplicationError, new_err.cause.cause.cause
      assert_equal orig_err.cause.cause.cause.backtrace, new_err.cause.cause.cause.backtrace
      assert_equal 'Unset error class', new_err.cause.cause.cause.message
      assert_equal 'RuntimeError', new_err.cause.cause.cause.type
    end

    # TODO(cretz): Test with encoded
  end
end
