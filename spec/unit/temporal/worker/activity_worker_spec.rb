require 'async'
require 'temporal/activity'
require 'temporal/bridge'
require 'temporal/data_converter'
require 'temporal/worker/activity_worker'
require 'temporal/worker/activity_runner'
require 'temporal/worker/thread_pool_executor'

class TestActivity < Temporal::Activity; end

class TestActivity2 < Temporal::Activity
  activity_name 'TestActivity'
end

class TestWrongSuperclassActivity < Object; end

describe Temporal::Worker::ActivityWorker do
  subject { described_class.new(task_queue, core_worker, activities, converter, executor) }

  let(:task_queue) { 'test-task-queue' }
  let(:activities) { [TestActivity] }
  let(:token) { 'test_token' }
  let(:core_worker) { instance_double(Temporal::Bridge::Worker) }
  let(:runner) { instance_double(Temporal::Worker::ActivityRunner) }
  let(:executor) { Temporal::Worker::ThreadPoolExecutor.new(1) }
  let(:converter) { Temporal::DataConverter.new }

  describe '#initialize' do
    context 'when initialized with an incorrect activity class' do
      let(:activities) { [TestWrongSuperclassActivity] }

      it 'raises an error' do
        expect { subject }
          .to raise_error(ArgumentError, 'Activity must be a subclass of Temporal::Activity')
      end
    end

    context 'when initialized with the same activity class twice' do
      let(:activities) { [TestActivity, TestActivity] }

      it 'raises an error' do
        expect { subject }
          .to raise_error(ArgumentError, 'More than one activity named TestActivity')
      end
    end

    context 'when initialized with the same activity name twice' do
      let(:activities) { [TestActivity, TestActivity2] }

      it 'raises an error' do
        expect { subject }
          .to raise_error(ArgumentError, 'More than one activity named TestActivity')
      end
    end
  end

  describe '#run' do
    let(:activity_name) { 'TestActivity' }

    before do
      allow(subject).to receive(:running?).and_return(true, false)
      allow(core_worker).to receive(:complete_activity_task).and_yield
      allow(core_worker).to receive(:poll_activity_task) do |&block|
        proto = Coresdk::ActivityTask::ActivityTask.new(
          task_token: token,
          start: Coresdk::ActivityTask::Start.new(
            activity_type: activity_name,
            input: [converter.to_payload('test')],
          )
        )
        block.call(proto.to_proto)
      end
      allow(Temporal::Worker::ActivityRunner).to receive(:new).and_return(runner)
    end

    context 'when activity is not registered' do
      let(:activity_name) { 'unknown-activity' }

      it 'responds with a failure' do
        Async { |task| subject.run(task) }

        expect(core_worker).to have_received(:complete_activity_task) do |bytes|
          proto = Coresdk::ActivityTaskCompletion.decode(bytes)
          expect(proto.task_token).to eq(token)
          expect(proto.result.failed.failure.message).to eq(
            'Activity unknown-activity is not registered on this worker, available activities: TestActivity'
          )
          expect(proto.result.failed.failure.application_failure_info.type).to eq('NotFoundError')
        end
      end
    end

    context 'when it succeeds' do
      before { allow(runner).to receive(:run).and_return(converter.to_payload('test result')) }

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
      before do
        allow(runner)
          .to receive(:run)
          .and_return(converter.to_failure(StandardError.new('test error')))
      end

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
