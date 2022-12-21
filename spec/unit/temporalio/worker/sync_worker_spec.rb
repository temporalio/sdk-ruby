require 'temporal/api/common/v1/message_pb'
require 'temporal/api/failure/v1/message_pb'
require 'temporalio/bridge'
require 'temporalio/worker/sync_worker'

describe Temporalio::Worker::SyncWorker do
  subject { described_class.new(core_worker) }
  let(:core_worker) { instance_double(Temporalio::Bridge::Worker) }
  let(:token) { 'test_token' }

  describe '#poll_activity_task' do
    context 'when call succeeds' do
      before do
        allow(core_worker).to receive(:poll_activity_task) do |&block|
          proto = Coresdk::ActivityTask::ActivityTask.new(task_token: token)
          block.call(proto.to_proto)
        end
      end

      it 'calls core worker and decodes the response' do
        task = subject.poll_activity_task

        expect(task).to be_a(Coresdk::ActivityTask::ActivityTask)
        expect(task.task_token).to eq(token)
        expect(core_worker).to have_received(:poll_activity_task)
      end
    end

    context 'when call fails' do
      let(:error) { Temporalio::Bridge::Error.new('test error') }

      before { allow(core_worker).to receive(:poll_activity_task).and_yield(nil, error) }

      it 'raises the error' do
        expect { subject.poll_activity_task }.to raise_error(error)
      end
    end
  end

  describe '#complete_activity_task_with_success' do
    let(:payload) { Temporalio::Api::Common::V1::Payload.new(data: 'test') }

    context 'when call succeeds' do
      before { allow(core_worker).to receive(:complete_activity_task).and_yield(nil, nil) }

      it 'sends an encoded response' do
        subject.complete_activity_task_with_success(token, payload)

        expect(core_worker).to have_received(:complete_activity_task) do |bytes|
          proto = Coresdk::ActivityTaskCompletion.decode(bytes)
          expect(proto.task_token).to eq(token)
          expect(proto.result.completed.result).to eq(payload)
        end
      end
    end

    context 'when call fails' do
      let(:error) { Temporalio::Bridge::Error.new('test error') }

      before { allow(core_worker).to receive(:complete_activity_task).and_yield(nil, error) }

      it 'raises the error' do
        expect { subject.complete_activity_task_with_success(token, payload) }.to raise_error(error)
      end
    end
  end

  describe '#complete_activity_task_with_failure' do
    let(:failure) do
      Temporalio::Api::Failure::V1::Failure.new(
        message: 'Test failure',
        terminated_failure_info: Temporalio::Api::Failure::V1::TerminatedFailureInfo.new,
      )
    end

    context 'when call succeeds' do
      before { allow(core_worker).to receive(:complete_activity_task).and_yield(nil, nil) }

      it 'sends an encoded response' do
        subject.complete_activity_task_with_failure(token, failure)

        expect(core_worker).to have_received(:complete_activity_task) do |bytes|
          proto = Coresdk::ActivityTaskCompletion.decode(bytes)
          expect(proto.task_token).to eq(token)
          expect(proto.result.failed.failure).to eq(failure)
        end
      end
    end

    context 'when call fails' do
      let(:error) { Temporalio::Bridge::Error.new('test error') }

      before { allow(core_worker).to receive(:complete_activity_task).and_yield(nil, error) }

      it 'raises the error' do
        expect { subject.complete_activity_task_with_failure(token, failure) }.to raise_error(error)
      end
    end
  end

  describe '#complete_activity_task_with_cancellation' do
    let(:failure) do
      Temporalio::Api::Failure::V1::Failure.new(
        message: 'Test cancellation',
        canceled_failure_info: Temporalio::Api::Failure::V1::CanceledFailureInfo.new,
      )
    end

    context 'when call succeeds' do
      before { allow(core_worker).to receive(:complete_activity_task).and_yield(nil, nil) }

      it 'sends an encoded response' do
        subject.complete_activity_task_with_cancellation(token, failure)

        expect(core_worker).to have_received(:complete_activity_task) do |bytes|
          proto = Coresdk::ActivityTaskCompletion.decode(bytes)
          expect(proto.task_token).to eq(token)
          expect(proto.result.cancelled.failure).to eq(failure)
        end
      end
    end

    context 'when call fails' do
      let(:error) { Temporalio::Bridge::Error.new('test error') }

      before { allow(core_worker).to receive(:complete_activity_task).and_yield(nil, error) }

      it 'raises the error' do
        expect { subject.complete_activity_task_with_cancellation(token, failure) }.to raise_error(error)
      end
    end
  end

  describe '#record_activity_heartbeat' do
    let(:payload) { Temporalio::Api::Common::V1::Payload.new(data: 'test') }

    before { allow(core_worker).to receive(:record_activity_heartbeat) }

    it 'sends an encoded response' do
      subject.record_activity_heartbeat(token, [payload])

      expect(core_worker).to have_received(:record_activity_heartbeat) do |bytes|
        proto = Coresdk::ActivityHeartbeat.decode(bytes)
        expect(proto.task_token).to eq(token)
        expect(proto.details.size).to eq(1)
        expect(proto.details.first).to eq(payload)
      end
    end
  end
end
