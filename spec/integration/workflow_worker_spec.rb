require 'support/helpers/test_rpc'
require 'temporalio/workflow'
require 'temporalio/bridge'
require 'temporalio/client'
require 'temporalio/testing'
require 'temporalio/worker'

class TestBasicWorkflow < Temporalio::Workflow
  def execute(name)
    "Hello, #{name}!"
  end
end

class TestMultiParamWorkflow < Temporalio::Workflow
  def execute(arg_1, arg_2, arg_3)
    [arg_1, arg_2, arg_3].join('-')
  end
end

class TestAsyncWorkflow < Temporalio::Workflow
  # TODO: add current time to check that up to [duration_1, duration_2].max has passed
  def execute(duration_1, duration_2)
    timer_1 = workflow.start_timer(duration_1)
    timer_2 = async { workflow.sleep(duration_2) }

    async.any(timer_1, timer_2).await

    result = timer_1.pending? ? 'second timer wins' : 'first timer wins'

    # Make sure all timers finish
    async.all(timer_1, timer_2).await

    result
  end
end

class TestCancellationsWorkflow < Temporalio::Workflow
  # TODO: add current time to check that up to [duration_1, duration_2].max has passed
  def execute(duration_1, duration_2)
    timer_1 = workflow.start_timer(duration_1)
    timer_2 = async { workflow.sleep(duration_2) }

    timer_1.then { timer_2.cancel }
    timer_2.then { timer_1.cancel }

    async.all(timer_1, timer_2).await

    timer_1.rejected? ? 'first timer cancelled' : 'second timer cancelled'
  end
end

class TestCombinedCancellationsWorkflow < Temporalio::Workflow
  # TODO: add current time to check that duration_1 has passed
  def execute(duration_1, duration_2)
    timer_1 = workflow.start_timer(duration_2)
    timer_2 = async { workflow.sleep(duration_2) }

    workflow.sleep(duration_1)

    combined_future = async.all(timer_1, timer_2)
    combined_future.cancel
    combined_future.await

    timer_1.rejected? && timer_2.rejected?
  end
end

describe Temporalio::Worker::WorkflowWorker do
  subject do
    Temporalio::Worker.new(
      connection,
      namespace,
      task_queue,
      workflows: [
        TestBasicWorkflow,
        TestMultiParamWorkflow,
        TestAsyncWorkflow,
        TestCancellationsWorkflow,
        TestCombinedCancellationsWorkflow,
      ],
    )
  end

  let(:namespace) { 'default' }
  let(:task_queue) { 'test-queue' }
  let(:env) { @env }
  let(:connection) { @env.connection }
  let(:client) { @env.client }
  let(:id) { SecureRandom.uuid }

  before(:all) do
    @env = Temporalio::Testing.start_time_skipping_environment(download_dir: './tmp/')
  end

  after(:all) do
    @env.shutdown
  end

  describe 'executing a workflow' do
    it 'runs a workflow and returns a result' do
      handle = client.start_workflow(TestBasicWorkflow, 'test', id: id, task_queue: task_queue)

      expect(subject.run { handle.result }).to eq('Hello, test!')
    end

    it 'runs a workflow with multiple params and returns a result' do
      handle = client.start_workflow(TestMultiParamWorkflow, 'one', 2, :three, id: id, task_queue: task_queue)

      expect(subject.run { handle.result }).to eq('one-2-three')
    end

    it 'runs a workflow with a timer' do
      handle_1 = client.start_workflow(TestAsyncWorkflow, 1, 2, id: SecureRandom.uuid, task_queue: task_queue)
      handle_2 = client.start_workflow(TestAsyncWorkflow, 2, 1, id: SecureRandom.uuid, task_queue: task_queue)

      subject.run { handle_1.result && handle_2.result }

      expect(handle_1.result).to eq('first timer wins')
      expect(handle_2.result).to eq('second timer wins')
    end

    it 'runs a workflow that cancels timers' do
      handle_1 = client.start_workflow(TestCancellationsWorkflow, 1, 2, id: SecureRandom.uuid, task_queue: task_queue)
      handle_2 = client.start_workflow(TestCancellationsWorkflow, 2, 1, id: SecureRandom.uuid, task_queue: task_queue)

      subject.run { handle_1.result && handle_2.result }

      expect(handle_1.result).to eq('second timer cancelled')
      expect(handle_2.result).to eq('first timer cancelled')
    end

    it 'runs a workflow that cancels a combined future' do
      handle = client.start_workflow(TestCombinedCancellationsWorkflow, 1, 2, id: id, task_queue: task_queue)

      subject.run { handle.result }

      expect(handle.result).to eq(true)
    end
  end
end
