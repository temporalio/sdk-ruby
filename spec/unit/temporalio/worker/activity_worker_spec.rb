require 'async'
require 'temporalio/activity'
require 'temporalio/bridge'
require 'temporalio/data_converter'
require 'temporalio/worker/activity_worker'
require 'temporalio/worker/activity_runner'
require 'temporalio/worker/thread_pool_executor'

class TestActivity < Temporalio::Activity; end

class TestActivity2 < Temporalio::Activity
  activity_name 'TestActivity'
end

class TestWrongSuperclassActivity < Object; end

describe Temporalio::Worker::ActivityWorker do
  subject { described_class.new(task_queue, core_worker, activities, converter, executor) }

  let(:task_queue) { 'test-task-queue' }
  let(:activities) { [TestActivity] }
  let(:token) { 'test_token' }
  let(:core_worker) { instance_double(Temporalio::Bridge::Worker) }
  let(:runner) { instance_double(Temporalio::Worker::ActivityRunner) }
  let(:executor) { Temporalio::Worker::ThreadPoolExecutor.new(1) }
  let(:converter) { Temporalio::DataConverter.new }

  describe '#initialize' do
    context 'when initialized with an incorrect activity class' do
      let(:activities) { [TestWrongSuperclassActivity] }

      it 'raises an error' do
        expect { subject }
          .to raise_error(ArgumentError, 'Activity must be a subclass of Temporalio::Activity')
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
      allow(core_worker).to receive(:complete_activity_task).and_yield(nil, nil)
      allow(core_worker).to receive(:poll_activity_task).and_invoke(
        ->(&block) { block.call(task.to_proto) },
        -> { raise(Temporalio::Bridge::Error::WorkerShutdown) },
      )
      allow(Temporalio::Worker::ActivityRunner).to receive(:new).and_return(runner)
    end

    context 'when processing a start task' do
      let(:task) do
        Coresdk::ActivityTask::ActivityTask.new(
          task_token: token,
          start: Coresdk::ActivityTask::Start.new(
            activity_type: activity_name,
            input: [converter.to_payload('test')],
          )
        )
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

      context 'when it gets cancelled' do
        before do
          allow(runner)
            .to receive(:run)
            .and_return(converter.to_failure(Temporalio::Error::CancelledError.new('test cancellation')))
        end

        context 'when cancellation was not requested' do
          it 'processes an activity task and sends back a regular failure' do
            Async { |task| subject.run(task) }

            expect(core_worker).to have_received(:complete_activity_task) do |bytes|
              proto = Coresdk::ActivityTaskCompletion.decode(bytes)
              expect(proto.task_token).to eq(token)
              expect(proto.result.failed.failure.message).to eq('test cancellation')
            end
          end
        end

        context 'when cancellation was requested' do
          # Simulate cancellation
          before { subject.instance_variable_get(:@cancellations) << token }

          it 'processes an activity task and sends back a cancellation' do
            Async { |task| subject.run(task) }

            expect(core_worker).to have_received(:complete_activity_task) do |bytes|
              proto = Coresdk::ActivityTaskCompletion.decode(bytes)
              expect(proto.task_token).to eq(token)
              expect(proto.result.cancelled.failure.message).to eq('test cancellation')
            end
          end
        end
      end
    end

    context 'when processing a cancel task' do
      let(:task) do
        Coresdk::ActivityTask::ActivityTask.new(
          task_token: token,
          cancel: Coresdk::ActivityTask::Cancel.new(
            reason: Coresdk::ActivityTask::ActivityCancelReason::CANCELLED,
          )
        )
      end

      context 'when task is running' do
        before do
          allow(subject).to receive(:running_activities).and_return(token => runner)
          allow(runner).to receive(:cancel)
        end

        it 'cancels the runner' do
          Async { |task| subject.run(task) }

          expect(runner).to have_received(:cancel)
        end
      end

      context 'when task is not running' do
        before { allow(subject).to receive(:warn) }

        it 'warns' do
          Async { |task| subject.run(task) }

          expect(subject)
            .to have_received(:warn)
            .with("Cannot find activity to cancel for token #{token}")
        end
      end
    end

    context 'when handling a fatal error' do
      let(:task) do
        Coresdk::ActivityTask::ActivityTask.new(
          task_token: token,
          start: Coresdk::ActivityTask::Start.new(
            activity_type: activity_name,
            input: [converter.to_payload('test')],
          )
        )
      end

      before do
        allow(runner).to receive(:run).and_return(converter.to_payload('test result'))
        allow(core_worker).to receive(:poll_activity_task).and_invoke(
          ->(&block) { block.call(task.to_proto) },
          -> { raise(Temporalio::Bridge::Error) },
        )
      end

      it 're-raises the error' do
        Async do |task|
          expect { subject.run(task) }.to raise_error(Temporalio::Bridge::Error)
        end
      end
    end
  end
end
