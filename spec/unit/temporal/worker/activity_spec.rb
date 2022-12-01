require 'async'
require 'temporal/bridge'
require 'temporal/data_converter'
require 'temporal/failure_converter'
require 'temporal/payload_converter'
require 'temporal/worker/activity'
require 'temporal/worker/activity_task_processor'
require 'temporal/worker/thread_pool_executor'

describe Temporal::Worker::Activity do
  subject { described_class.new(core_worker, converter, executor) }
  let(:token) { 'test_token' }
  let(:core_worker) { instance_double(Temporal::Bridge::Worker) }
  let(:processor) { instance_double(Temporal::Worker::ActivityTaskProcessor) }
  let(:executor) { Temporal::Worker::ThreadPoolExecutor.new(1) }
  let(:converter) do
    Temporal::DataConverter.new(
      payload_converter: Temporal::PayloadConverter::DEFAULT,
      payload_codecs: [],
      failure_converter: Temporal::FailureConverter::DEFAULT,
    )
  end

  describe '#run' do
    before do
      allow(subject).to receive(:running?).and_return(true, false)
      allow(core_worker).to receive(:complete_activity_task).and_yield
      allow(core_worker).to receive(:poll_activity_task) do |&block|
        proto = Coresdk::ActivityTask::ActivityTask.new(
          task_token: token,
          start: Coresdk::ActivityTask::Start.new(activity_id: '42')
        )
        block.call(proto.to_proto)
      end
      allow(Temporal::Worker::ActivityTaskProcessor).to receive(:new).and_return(processor)
    end

    context 'when it succeeds' do
      before { allow(processor).to receive(:process).and_return('test result') }

      it 'processes an activity task and sends back the result' do
        Async { |task| subject.run(task) }

        expect(core_worker).to have_received(:complete_activity_task) do |bytes|
          proto = Coresdk::ActivityTaskCompletion.decode(bytes)
          expect(proto.task_token).to eq(token)
          expect(proto.result.completed.result.data).to eq('"test result"')
        end
      end
    end

    context 'when it raises an error' do
      before { allow(processor).to receive(:process).and_raise(StandardError.new('test error')) }

      it 'processes an activity task and sends back the failure' do
        Async { |task| subject.run(task) }

        expect(core_worker).to have_received(:complete_activity_task) do |bytes|
          proto = Coresdk::ActivityTaskCompletion.decode(bytes)
          expect(proto.task_token).to eq(token)
          expect(proto.result.failed.failure.message).to eq('test error')
        end
      end
    end
  end
end
