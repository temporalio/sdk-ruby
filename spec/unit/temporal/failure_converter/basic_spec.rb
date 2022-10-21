require 'temporal/failure_converter/basic'
require 'temporal/payload_converter'

describe Temporal::FailureConverter::Basic do
  subject { described_class.new(payload_converter: converter) }
  let(:converter) { Temporal::PayloadConverter::DEFAULT }

  before do
    allow(converter).to receive(:to_payload).and_call_original
    allow(converter).to receive(:from_payload).and_call_original
  end

  describe '#to_failure' do

  end

  describe '#from_failure' do
    let(:details) { { 'foo' => 'bar' } }
    let(:payload) { converter.to_payload(details) }
    let(:failure) do
      Temporal::Api::Failure::V1::Failure.new(
        message: 'Test failure',
        stack_trace: "foo.rb:1 in `foo`\nbar.rb:4 in `bar`",
      )
    end

    context 'with missing failure info' do
      it 'returns an error' do
        error = subject.from_failure(failure)

        expect(error).to be_a(Temporal::Error::Failure)
        expect(error.message).to eq('Test failure')
        expect(error.raw).to eq(failure)
        expect(error.backtrace).to eq(['foo.rb:1 in `foo`', 'bar.rb:4 in `bar`'])
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
        expect(error.backtrace).to eq(['foo.rb:1 in `foo`', 'bar.rb:4 in `bar`'])
        expect(error.cause).to eq(nil)

        expect(converter).to have_received(:from_payload).with(payload)
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
        expect(error.type).to eq(:TIMEOUT_TYPE_SCHEDULE_TO_START)
        expect(error.last_heartbeat_details).to eq([details])
        expect(error.raw).to eq(failure)
        expect(error.backtrace).to eq(['foo.rb:1 in `foo`', 'bar.rb:4 in `bar`'])
        expect(error.cause).to eq(nil)

        expect(converter).to have_received(:from_payload).with(payload)
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
        expect(error.backtrace).to eq(['foo.rb:1 in `foo`', 'bar.rb:4 in `bar`'])
        expect(error.cause).to eq(nil)

        expect(converter).to have_received(:from_payload).with(payload)
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
        expect(error.backtrace).to eq(['foo.rb:1 in `foo`', 'bar.rb:4 in `bar`'])
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
        expect(error.backtrace).to eq(['foo.rb:1 in `foo`', 'bar.rb:4 in `bar`'])
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
        expect(error.backtrace).to eq(['foo.rb:1 in `foo`', 'bar.rb:4 in `bar`'])
        expect(error.cause).to eq(nil)

        expect(converter).to have_received(:from_payload).with(payload)
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
        expect(error.retry_state).to eq(:RETRY_STATE_MAXIMUM_ATTEMPTS_REACHED)
        expect(error.raw).to eq(failure)
        expect(error.backtrace).to eq(['foo.rb:1 in `foo`', 'bar.rb:4 in `bar`'])
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
        expect(error.retry_state).to eq(:RETRY_STATE_MAXIMUM_ATTEMPTS_REACHED)
        expect(error.raw).to eq(failure)
        expect(error.backtrace).to eq(['foo.rb:1 in `foo`', 'bar.rb:4 in `bar`'])
        expect(error.cause).to eq(nil)
      end
    end
  end
end
