require 'temporal/failure_converter/basic'
require 'temporal/payload_converter'

describe Temporal::FailureConverter::Basic do
  subject { described_class.new(payload_converter: converter) }
  let(:converter) { Temporal::PayloadConverter::DEFAULT }
  let(:details) { { 'foo' => 'bar' } }
  let(:payload) { converter.to_payload(details) }
  let(:backtrace) { ['foo.rb:1 in `foo`', 'bar.rb:4 in `bar`'] }
  let(:stack_trace) { "foo.rb:1 in `foo`\nbar.rb:4 in `bar`" }

  before do
    allow(converter).to receive(:to_payload).and_call_original
    allow(converter).to receive(:from_payload).and_call_original
  end

  describe '#to_failure' do
    before { error.set_backtrace(backtrace) }

    context 'with ApplicationError' do
      let(:error) do
        Temporal::Error::ApplicationError.new(
          'Test error',
          type: 'Test type',
          details: [details],
          non_retryable: true,
        )
      end

      it 'returns a failure' do
        failure = subject.to_failure(error)

        expect(converter).to have_received(:to_payload).with(details).once

        expect(failure).to be_a(Temporal::Api::Failure::V1::Failure)
        expect(failure.message).to eq('Test error')
        expect(failure.stack_trace).to eq(stack_trace)
        expect(failure.cause).to eq(nil)
        expect(failure.application_failure_info.type).to eq('Test type')
        expect(failure.application_failure_info.non_retryable).to eq(true)
        expect(failure.application_failure_info.details.payloads).to eq([payload])
      end
    end

    context 'with TimeoutError' do
      let(:error) do
        Temporal::Error::TimeoutError.new(
          'Test error',
          type: Temporal::TimeoutType::SCHEDULE_TO_START,
          last_heartbeat_details: [details],
        )
      end

      it 'returns a failure' do
        failure = subject.to_failure(error)

        expect(converter).to have_received(:to_payload).with(details).once

        expect(failure).to be_a(Temporal::Api::Failure::V1::Failure)
        expect(failure.message).to eq('Test error')
        expect(failure.stack_trace).to eq(stack_trace)
        expect(failure.cause).to eq(nil)
        expect(failure.timeout_failure_info.timeout_type).to eq(:TIMEOUT_TYPE_SCHEDULE_TO_START)
        expect(failure.timeout_failure_info.last_heartbeat_details.payloads).to eq([payload])
      end
    end

    context 'with CancelledError' do
      let(:error) do
        Temporal::Error::CancelledError.new('Test error', details: [details])
      end

      it 'returns a failure' do
        failure = subject.to_failure(error)

        expect(converter).to have_received(:to_payload).with(details).once

        expect(failure).to be_a(Temporal::Api::Failure::V1::Failure)
        expect(failure.message).to eq('Test error')
        expect(failure.stack_trace).to eq(stack_trace)
        expect(failure.cause).to eq(nil)
        expect(failure.canceled_failure_info.details.payloads).to eq([payload])
      end
    end

    context 'with TerminatedError' do
      let(:error) do
        Temporal::Error::TerminatedError.new('Test error')
      end

      it 'returns a failure' do
        failure = subject.to_failure(error)

        expect(failure).to be_a(Temporal::Api::Failure::V1::Failure)
        expect(failure.message).to eq('Test error')
        expect(failure.stack_trace).to eq(stack_trace)
        expect(failure.cause).to eq(nil)
        expect(failure.terminated_failure_info).not_to eq(nil)
      end
    end

    context 'with ServerError' do
      let(:error) do
        Temporal::Error::ServerError.new('Test error', non_retryable: true)
      end

      it 'returns a failure' do
        failure = subject.to_failure(error)

        expect(failure).to be_a(Temporal::Api::Failure::V1::Failure)
        expect(failure.message).to eq('Test error')
        expect(failure.stack_trace).to eq(stack_trace)
        expect(failure.cause).to eq(nil)
        expect(failure.server_failure_info.non_retryable).to eq(true)
      end
    end

    context 'with ResetWorkflowError' do
      let(:error) do
        Temporal::Error::ResetWorkflowError.new('Test error', last_heartbeat_details: [details])
      end

      it 'returns a failure' do
        failure = subject.to_failure(error)

        expect(converter).to have_received(:to_payload).with(details).once

        expect(failure).to be_a(Temporal::Api::Failure::V1::Failure)
        expect(failure.message).to eq('Test error')
        expect(failure.stack_trace).to eq(stack_trace)
        expect(failure.cause).to eq(nil)
        expect(failure.reset_workflow_failure_info.last_heartbeat_details.payloads).to eq([payload])
      end
    end

    context 'with ActivityError' do
      let(:error) do
        Temporal::Error::ActivityError.new(
          'Test error',
          scheduled_event_id: 1,
          started_event_id: 2,
          identity: 'test-identity',
          activity_name: 'test-activity',
          activity_id: 'test-activity-id',
          retry_state: Temporal::RetryState::MAXIMUM_ATTEMPTS_REACHED,
        )
      end

      it 'returns a failure' do
        failure = subject.to_failure(error)

        expect(failure).to be_a(Temporal::Api::Failure::V1::Failure)
        expect(failure.message).to eq('Test error')
        expect(failure.stack_trace).to eq(stack_trace)
        expect(failure.cause).to eq(nil)
        expect(failure.activity_failure_info.scheduled_event_id).to eq(1)
        expect(failure.activity_failure_info.started_event_id).to eq(2)
        expect(failure.activity_failure_info.identity).to eq('test-identity')
        expect(failure.activity_failure_info.activity_type.name).to eq('test-activity')
        expect(failure.activity_failure_info.activity_id).to eq('test-activity-id')
        expect(failure.activity_failure_info.retry_state)
          .to eq(:RETRY_STATE_MAXIMUM_ATTEMPTS_REACHED)
      end
    end

    context 'with ChildWorkflowError' do
      let(:error) do
        Temporal::Error::ChildWorkflowError.new(
          'Test error',
          namespace: 'test-namespace',
          workflow_id: 'test-workflow-id',
          run_id: 'test-run-id',
          workflow_name: 'test-workflow',
          initiated_event_id: 1,
          started_event_id: 2,
          retry_state: Temporal::RetryState::MAXIMUM_ATTEMPTS_REACHED,
        )
      end

      it 'returns a failure' do
        failure = subject.to_failure(error)
        failure_info = failure.child_workflow_execution_failure_info

        expect(failure).to be_a(Temporal::Api::Failure::V1::Failure)
        expect(failure.message).to eq('Test error')
        expect(failure.stack_trace).to eq(stack_trace)
        expect(failure.cause).to eq(nil)
        expect(failure_info.namespace).to eq('test-namespace')
        expect(failure_info.workflow_execution.workflow_id).to eq('test-workflow-id')
        expect(failure_info.workflow_execution.run_id).to eq('test-run-id')
        expect(failure_info.workflow_type.name).to eq('test-workflow')
        expect(failure_info.initiated_event_id).to eq(1)
        expect(failure_info.started_event_id).to eq(2)
        expect(failure_info.retry_state).to eq(:RETRY_STATE_MAXIMUM_ATTEMPTS_REACHED)
      end
    end

    context 'with user defined error' do
      let(:error) { StandardError.new('Test error') }

      it 'returns a failure' do
        failure = subject.to_failure(error)

        expect(failure).to be_a(Temporal::Api::Failure::V1::Failure)
        expect(failure.message).to eq('Test error')
        expect(failure.stack_trace).to eq(stack_trace)
        expect(failure.cause).to eq(nil)
        expect(failure.application_failure_info.type).to eq('StandardError')
        expect(failure.application_failure_info.non_retryable).to eq(false)
        expect(failure.application_failure_info.details).to eq(nil)
      end
    end

    context 'when encode_common_attributes is set to true' do
      subject { described_class.new(payload_converter: converter, encode_common_attributes: true) }
      let(:error) { StandardError.new('Test error') }

      it 'encodes attributes' do
        failure = subject.to_failure(error)

        expect(failure.message).to eq('Encoded failure')
        expect(failure.stack_trace).to be_empty
        expect(failure.encoded_attributes).to be_a(Temporal::Api::Common::V1::Payload)
        expect(converter.from_payload(failure.encoded_attributes)).to eq(
          'message' => 'Test error',
          'stack_trace' => stack_trace,
        )
      end
    end
  end

  describe '#from_failure' do
    let(:failure) do
      Temporal::Api::Failure::V1::Failure.new(
        message: 'Test failure',
        stack_trace: stack_trace,
      )
    end

    context 'with missing failure info' do
      it 'returns an error' do
        error = subject.from_failure(failure)

        expect(error).to be_a(Temporal::Error::Failure)
        expect(error.message).to eq('Test failure')
        expect(error.raw).to eq(failure)
        expect(error.backtrace).to eq(backtrace)
        expect(error.cause).to eq(nil)
      end
    end

    context 'with application failure info' do
      let(:failure_info) do
        Temporal::Api::Failure::V1::ApplicationFailureInfo.new(
          type: 'Test application error',
          non_retryable: true,
          details: { payloads: [payload] },
        )
      end

      before { failure.application_failure_info = failure_info }

      it 'returns an error' do
        error = subject.from_failure(failure)

        expect(error).to be_a(Temporal::Error::ApplicationError)
        expect(error.message).to eq('Test failure')
        expect(error.type).to eq('Test application error')
        expect(error.details).to eq([details])
        expect(error.non_retryable).to eq(true)
        expect(error).not_to be_retryable
        expect(error.raw).to eq(failure)
        expect(error.backtrace).to eq(backtrace)
        expect(error.cause).to eq(nil)

        expect(converter).to have_received(:from_payload).with(payload).once
      end
    end

    context 'with timeout failure info' do
      let(:failure_info) do
        Temporal::Api::Failure::V1::TimeoutFailureInfo.new(
          timeout_type: Temporal::Api::Enums::V1::TimeoutType::TIMEOUT_TYPE_SCHEDULE_TO_START,
          last_heartbeat_details: { payloads: [payload] },
        )
      end

      before { failure.timeout_failure_info = failure_info }

      it 'returns an error' do
        error = subject.from_failure(failure)

        expect(error).to be_a(Temporal::Error::TimeoutError)
        expect(error.message).to eq('Test failure')
        expect(error.type).to eq(Temporal::TimeoutType::SCHEDULE_TO_START)
        expect(error.last_heartbeat_details).to eq([details])
        expect(error.raw).to eq(failure)
        expect(error.backtrace).to eq(backtrace)
        expect(error.cause).to eq(nil)

        expect(converter).to have_received(:from_payload).with(payload).once
      end
    end

    context 'with canceled failure info' do
      let(:failure_info) do
        Temporal::Api::Failure::V1::CanceledFailureInfo.new(
          details: { payloads: [payload] },
        )
      end

      before { failure.canceled_failure_info = failure_info }

      it 'returns an error' do
        error = subject.from_failure(failure)

        expect(error).to be_a(Temporal::Error::CancelledError)
        expect(error.message).to eq('Test failure')
        expect(error.details).to eq([details])
        expect(error.raw).to eq(failure)
        expect(error.backtrace).to eq(backtrace)
        expect(error.cause).to eq(nil)

        expect(converter).to have_received(:from_payload).with(payload).once
      end
    end

    context 'with terminated failure info' do
      let(:failure_info) { Temporal::Api::Failure::V1::TerminatedFailureInfo.new }

      before { failure.terminated_failure_info = failure_info }

      it 'returns an error' do
        error = subject.from_failure(failure)

        expect(error).to be_a(Temporal::Error::TerminatedError)
        expect(error.message).to eq('Test failure')
        expect(error.raw).to eq(failure)
        expect(error.backtrace).to eq(backtrace)
        expect(error.cause).to eq(nil)
      end
    end

    context 'with server failure info' do
      let(:failure_info) { Temporal::Api::Failure::V1::ServerFailureInfo.new(non_retryable: true) }

      before { failure.server_failure_info = failure_info }

      it 'returns an error' do
        error = subject.from_failure(failure)

        expect(error).to be_a(Temporal::Error::ServerError)
        expect(error.message).to eq('Test failure')
        expect(error.non_retryable).to eq(true)
        expect(error).not_to be_retryable
        expect(error.raw).to eq(failure)
        expect(error.backtrace).to eq(backtrace)
        expect(error.cause).to eq(nil)
      end
    end

    context 'with reset workflow failure info' do
      let(:failure_info) do
        Temporal::Api::Failure::V1::ResetWorkflowFailureInfo.new(
          last_heartbeat_details: { payloads: [payload] },
        )
      end

      before { failure.reset_workflow_failure_info = failure_info }

      it 'returns an error' do
        error = subject.from_failure(failure)

        expect(error).to be_a(Temporal::Error::ResetWorkflowError)
        expect(error.message).to eq('Test failure')
        expect(error.last_heartbeat_details).to eq([details])
        expect(error.raw).to eq(failure)
        expect(error.backtrace).to eq(backtrace)
        expect(error.cause).to eq(nil)

        expect(converter).to have_received(:from_payload).with(payload).once
      end
    end

    context 'with activity failure info' do
      let(:failure_info) do
        Temporal::Api::Failure::V1::ActivityFailureInfo.new(
          scheduled_event_id: 1,
          started_event_id: 2,
          identity: 'test-identity',
          activity_type: { name: 'test-activity' },
          activity_id: 'test-activity-id',
          retry_state: Temporal::Api::Enums::V1::RetryState::RETRY_STATE_MAXIMUM_ATTEMPTS_REACHED,
        )
      end

      before { failure.activity_failure_info = failure_info }

      it 'returns an error' do
        error = subject.from_failure(failure)

        expect(error).to be_a(Temporal::Error::ActivityError)
        expect(error.message).to eq('Test failure')
        expect(error.scheduled_event_id).to eq(1)
        expect(error.started_event_id).to eq(2)
        expect(error.identity).to eq('test-identity')
        expect(error.activity_name).to eq('test-activity')
        expect(error.activity_id).to eq('test-activity-id')
        expect(error.retry_state).to eq(Temporal::RetryState::MAXIMUM_ATTEMPTS_REACHED)
        expect(error.raw).to eq(failure)
        expect(error.backtrace).to eq(backtrace)
        expect(error.cause).to eq(nil)
      end
    end

    context 'with child workflow execution failure info' do
      let(:failure_info) do
        Temporal::Api::Failure::V1::ChildWorkflowExecutionFailureInfo.new(
          namespace: 'test-namespace',
          workflow_execution: { workflow_id: 'test-workflow-id', run_id: 'test-run-id' },
          workflow_type: { name: 'test-workflow' },
          initiated_event_id: 1,
          started_event_id: 2,
          retry_state: Temporal::Api::Enums::V1::RetryState::RETRY_STATE_MAXIMUM_ATTEMPTS_REACHED,
        )
      end

      before { failure.child_workflow_execution_failure_info = failure_info }

      it 'returns an error' do
        error = subject.from_failure(failure)

        expect(error).to be_a(Temporal::Error::ChildWorkflowError)
        expect(error.message).to eq('Test failure')
        expect(error.namespace).to eq('test-namespace')
        expect(error.workflow_id).to eq('test-workflow-id')
        expect(error.run_id).to eq('test-run-id')
        expect(error.workflow_name).to eq('test-workflow')
        expect(error.initiated_event_id).to eq(1)
        expect(error.started_event_id).to eq(2)
        expect(error.retry_state).to eq(Temporal::RetryState::MAXIMUM_ATTEMPTS_REACHED)
        expect(error.raw).to eq(failure)
        expect(error.backtrace).to eq(backtrace)
        expect(error.cause).to eq(nil)
      end
    end

    context 'with encoded attributes' do
      it 'applies encoded attributes' do
        failure.encoded_attributes = converter.to_payload(
          'message' => 'Encoded message',
          'stack_trace' => "a.rb:1\nb.rb:2",
        )

        error = subject.from_failure(failure)

        expect(error.message).to eq('Encoded message')
        expect(error.backtrace).to eq(['a.rb:1', 'b.rb:2'])
      end

      it 'ignores unsupported attributes' do
        failure.encoded_attributes = converter.to_payload({ 'foo' => 'bar' })

        error = subject.from_failure(failure)

        expect(error.message).to eq('Test failure')
        expect(error.backtrace).to eq(backtrace)
      end
    end
  end
end
