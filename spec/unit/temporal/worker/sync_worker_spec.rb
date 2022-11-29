require 'temporal/api/common/v1/message_pb'
require 'temporal/api/failure/v1/message_pb'
require 'temporal/bridge'
require 'temporal/worker/sync_worker'

describe Temporal::Worker::SyncWorker do
  subject { described_class.new(core_worker) }
  let(:core_worker) { instance_double(Temporal::Bridge::Worker) }
  let(:token) { 'test_token' }

  describe '#poll_activity_task' do
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

  describe '#complete_activity_task_with_success' do
    let(:payload) { Temporal::Api::Common::V1::Payload.new(data: 'test') }

    before { allow(core_worker).to receive(:complete_activity_task).and_yield }

    it 'sends an encoded response' do
      subject.complete_activity_task_with_success(token, payload)

      expect(core_worker).to have_received(:complete_activity_task) do |bytes|
        proto = Coresdk::ActivityTaskCompletion.decode(bytes)
        expect(proto.task_token).to eq(token)
        expect(proto.result.completed.result).to eq(payload)
      end
    end
  end

  describe '#complete_activity_task_with_failure' do
    let(:failure) { Temporal::Api::Failure::V1::Failure.new(message: 'Test failure') }

    before { allow(core_worker).to receive(:complete_activity_task).and_yield }

    it 'sends an encoded response' do
      subject.complete_activity_task_with_failure(token, failure)

      expect(core_worker).to have_received(:complete_activity_task) do |bytes|
        proto = Coresdk::ActivityTaskCompletion.decode(bytes)
        expect(proto.task_token).to eq(token)
        expect(proto.result.failed.failure).to eq(failure)
      end
    end
  end
end
