require 'temporal/worker'
require 'temporal/async_reactor'

describe Temporal::Worker do
  # rubocop:disable Style/OpenStructUse
  let(:worker) { described_class.new(connection, 'default-ns', 'default-task-queue', reactor, executor) }
  let(:reactor) { Temporal::AsyncReactor.new }
  let(:executor) { Temporal::Executors.new }

  # TODO: Properly stub core bridge worker for unit testing
  let(:connection) { OpenStruct.new(core_connection: instance_double('Rutie::Connection')) }
  let(:bridge_worker) { OpenStruct.new(poll_activity_task: core_task) }
  let(:core_task) { OpenStruct.new }
  let(:decoded_task) { OpenStruct.new(start: start) }
  let(:start) do
    instance_double('Temporal::Start', workflow_execution: workflow_execution, activity_id: 'test-activity-id-1')
  end
  let(:workflow_execution) { instance_double('Temporal::WorkflowExecution', run_id: 'test-run-id-1') }
  # rubocop:enable Style/OpenStructUse

  before do
    Thread.abort_on_exception = true
    allow(Temporal::Bridge::Worker).to receive(:create).and_return(bridge_worker)
    allow(bridge_worker).to receive(:poll_activity_task).and_yield(core_task)
    allow(Coresdk::ActivityTask::ActivityTask).to receive(:decode).with(core_task).and_return(decoded_task)
  end

  describe '#run' do
    it 'polls and executes activity tasks in a loop' do
      expect(executor).to receive(:execute).with(decoded_task).at_least(10).times

      thread1 = Thread.new { worker.run }
      thread2 = Thread.new do
        sleep(0.1)
        worker.terminate
      end
      [thread1, thread2].each(&:join)
    end

    context 'when worker is already running' do
      it 'raises an error' do
        allow(executor).to receive(:execute)
        Thread.new { worker.run }
        sleep(0.1)
        expect { worker.run }.to raise_error(Temporal::Worker::AlreadyStartedError)
      end
    end
  end

  describe '#terminate' do
    it 'terminates all resources' do
      expect(executor).to receive(:terminate).and_call_original
      expect(reactor).to receive(:terminate).and_call_original
      worker.terminate
    end
  end
end
