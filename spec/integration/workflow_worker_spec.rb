require 'support/helpers/test_rpc'
require 'support/helpers/test_capture_interceptor'
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

class TestFailingWorkflow < Temporalio::Workflow
  def execute
    raise 'test error'
  end
end

class TestAsyncWorkflow < Temporalio::Workflow
  def execute(duration_1, duration_2)
    start_time = workflow.time

    timer_1 = workflow.start_timer(duration_1)
    timer_2 = async { workflow.sleep(duration_2) }

    async.any(timer_1, timer_2).await

    result = timer_1.pending? ? 'second timer wins' : 'first timer wins'

    # Make sure all timers finish
    async.all(timer_1, timer_2).await

    [result, workflow.time - start_time]
  end
end

class TestCancellationsWorkflow < Temporalio::Workflow
  def execute(duration_1, duration_2)
    start_time = workflow.time

    timer_1 = workflow.start_timer(duration_1)
    timer_2 = async { workflow.sleep(duration_2) }

    timer_1.then { timer_2.cancel }
    timer_2.then { timer_1.cancel }

    async.all(timer_1, timer_2).await

    result = timer_1.rejected? ? 'first timer cancelled' : 'second timer cancelled'

    [result, workflow.time - start_time]
  end
end

class TestCombinedCancellationsWorkflow < Temporalio::Workflow
  def execute(duration_1, duration_2)
    start_time = workflow.time

    timer_1 = workflow.start_timer(duration_2)
    timer_2 = async { workflow.sleep(duration_2) }

    workflow.sleep(duration_1)

    combined_future = async.all(timer_1, timer_2)
    combined_future.cancel
    combined_future.await

    [timer_1.rejected? && timer_2.rejected?, workflow.time - start_time]
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
        TestFailingWorkflow,
        TestAsyncWorkflow,
        TestCancellationsWorkflow,
        TestCombinedCancellationsWorkflow,
      ],
      interceptors: [interceptor],
    )
  end

  let(:namespace) { 'default' }
  let(:task_queue) { 'test-queue' }
  let(:env) { @env }
  let(:connection) { @env.connection }
  let(:client) { @env.client }
  let(:id) { SecureRandom.uuid }
  let(:interceptor) { Helpers::TestCaptureInterceptor.new }

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
      expect(interceptor.called_methods).to eq(%i[execute_workflow])
    end

    it 'runs a workflow with multiple params and returns a result' do
      handle = client.start_workflow(TestMultiParamWorkflow, 'one', 2, :three, id: id, task_queue: task_queue)

      expect(subject.run { handle.result }).to eq('one-2-three')
      expect(interceptor.called_methods).to eq(%i[execute_workflow])
    end

    it 'runs a failing and returns the failure' do
      handle = client.start_workflow(TestFailingWorkflow, id: id, task_queue: task_queue)

      expect { subject.run { handle.result } }.to raise_error do |error|
        expect(error).to be_a(Temporalio::Error::WorkflowFailure)
        expect(error.cause).to be_a(Temporalio::Error::ApplicationError)
        expect(error.cause.message).to eq('test error')
      end
      expect(interceptor.called_methods).to eq(%i[execute_workflow])
    end

    it 'runs a workflow with a timer' do
      handle_1 = client.start_workflow(TestAsyncWorkflow, 1, 2, id: SecureRandom.uuid, task_queue: task_queue)
      handle_2 = client.start_workflow(TestAsyncWorkflow, 2, 1, id: SecureRandom.uuid, task_queue: task_queue)

      subject.run { handle_1.result && handle_2.result }

      expect(handle_1.result.first).to eq('first timer wins')
      expect(handle_1.result.last).to be_within(0.1).of(2) # Make sure we didn't wait serially
      expect(handle_2.result.first).to eq('second timer wins')
      expect(handle_2.result.last).to be_within(0.1).of(2) # Make sure we didn't wait serially
      expect(interceptor.called_methods).to eq(%i[execute_workflow execute_workflow])
    end

    it 'runs a workflow that cancels timers' do
      handle_1 = client.start_workflow(TestCancellationsWorkflow, 1, 2, id: SecureRandom.uuid, task_queue: task_queue)
      handle_2 = client.start_workflow(TestCancellationsWorkflow, 2, 1, id: SecureRandom.uuid, task_queue: task_queue)

      subject.run { handle_1.result && handle_2.result }

      expect(handle_1.result.first).to eq('second timer cancelled')
      expect(handle_1.result.last).to be_within(0.1).of(1) # Make sure we didn't wait for the longer timer
      expect(handle_2.result.first).to eq('first timer cancelled')
      expect(handle_2.result.last).to be_within(0.1).of(1) # Make sure we didn't wait for the longer timer
      expect(interceptor.called_methods).to eq(%i[execute_workflow execute_workflow])
    end

    it 'runs a workflow that cancels a combined future' do
      handle = client.start_workflow(TestCombinedCancellationsWorkflow, 1, 2, id: id, task_queue: task_queue)

      subject.run { handle.result }

      expect(handle.result.first).to eq(true)
      expect(handle.result.last).to be_within(0.1).of(1) # Make sure we only waited for the first timer
      expect(interceptor.called_methods).to eq(%i[execute_workflow])
    end
  end
end
