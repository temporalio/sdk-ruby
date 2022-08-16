require 'temporal/worker'
require 'temporal/async_reactor'

describe Temporal::Worker do
  let(:worker) { described_class.new(connection, 'default-ns', 'default-task-queue', reactor, executor) }
  let(:reactor) { Temporal::AsyncReactor.new }
  let(:executor) { Temporal::Executors.new }
  let(:connection) { instance_double('Temporal::Connection', core_connection: instance_double('Rutie::COnnection')) }
  let(:bridge_worker) { instance_double('Temporal::Bridge::Worker', :poll_activity_task) }
  let(:core_task) { instance_double('Temporal::Task') }
  let(:decoded_task) { instance_double('Temporal::Task', start: start) }
  let(:start) do
    instance_double('Temporal::Start', workflow_execution: workflow_execution, activity_id: 'test-activity-id-1')
  end
  let(:workflow_execution) { instance_double('Temporal::WorkflowExecution', run_id: 'test-run-id-1') }

  before do
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
  end

  describe '#terminate' do
    it 'terminates all resources' do
      expect(executor).to receive(:terminate).and_call_original
      expect(reactor).to receive(:terminate).and_call_original
      worker.terminate
    end
  end
end
