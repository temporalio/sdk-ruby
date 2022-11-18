require 'securerandom'
require 'temporal/client'
require 'temporal/connection'
require 'temporal/error/failure'
require 'temporal/error/workflow_failure'
require 'temporal/interceptor/client'
require 'support/helpers/test_rpc'

class TestInterceptor < Temporal::Interceptor::Client
  attr_reader :results

  def initialize
    @results = []
    super
  end

  def start_workflow(input)
    results << [:start_workflow, input.workflow]
    super
  end

  def describe_workflow(input)
    results << [:describe_workflow, input.id]
    super
  end

  def query_workflow(input)
    results << [:query_workflow, input.query]
    super
  end

  def signal_workflow(input)
    results << [:signal_workflow, input.signal]
    super
  end

  def cancel_workflow(input)
    results << [:cancel_workflow, input.id]
    super
  end

  def terminate_workflow(input)
    results << [:terminate_workflow, input.id]
    super
  end
end

describe Temporal::Client do
  support_path = 'spec/support'.freeze
  port = 5555
  task_queue = 'test-client'.freeze
  namespace = 'ruby-samples'.freeze
  url = "localhost:#{port}".freeze

  subject { described_class.new(connection, namespace) }

  let(:connection) { Temporal::Connection.new(url) }
  let(:id) { SecureRandom.uuid }
  let(:workflow) { 'kitchen_sink' }

  before(:all) do
    @server_pid = fork { exec("#{support_path}/go_server/main #{port} #{namespace}") }
    Helpers::TestRPC.wait(url, 10, 0.5)

    @worker_pid = fork { exec("#{support_path}/go_worker/main #{url} #{namespace} #{task_queue}") }
  end

  after(:all) do
    Process.kill('INT', @worker_pid)
    Process.wait(@worker_pid)
    Process.kill('INT', @server_pid)
    Process.wait(@server_pid)
  end

  describe 'starting a workflow' do
    it 'runs a workflow and waits for a result' do
      input = { actions: [{ result: { value: 'test return value' } }] }
      handle = subject.start_workflow(workflow, input, id: id, task_queue: task_queue)

      expect(handle.result).to eq('test return value')
    end

    it 'respects ID reuse policy' do
      input = { actions: [{ result: { value: 'test return value 1' } }] }
      handle = subject.start_workflow(workflow, input, id: id, task_queue: task_queue)

      expect(handle.result).to eq('test return value 1')

      # Run with REJECT_DUPLICATE expecting a rejection
      input = { actions: [{ result: { value: 'test return value 2' } }] }
      expect do
        subject.start_workflow(
          workflow,
          input,
          id: id,
          task_queue: task_queue,
          id_reuse_policy: Temporal::Workflow::IDReusePolicy::REJECT_DUPLICATE,
        )
      end.to raise_error(
        Temporal::Error::WorkflowExecutionAlreadyStarted,
        'Workflow execution already started'
      )

      # Run with a default policy again expecting it to succeed
      input = { actions: [{ result: { value: 'test return value 3' } }] }
      handle = subject.start_workflow(workflow, input, id: id, task_queue: task_queue)

      expect(handle.result).to eq('test return value 3')
    end

    it 'starts a workflow with a signal' do
      handle = subject.start_workflow(
        workflow,
        { action_signal: 'test-signal' },
        id: id,
        task_queue: task_queue,
        start_signal: 'test-signal',
        start_signal_args: [{ result: { value: 'test signal arg' } }],
      )

      expect(handle.result).to eq('test signal arg')
    end
  end

  describe 'describing a workflow' do
    it 'returns workflow execution info' do
      input = { actions: [{ result: { value: 'test return value' } }] }
      handle = subject.start_workflow(workflow, input, id: id, task_queue: task_queue)

      expect(handle.result).to eq('test return value')

      info = handle.describe

      expect(info.workflow).to eq(workflow)
      expect(info.task_queue).to eq(task_queue)
      expect(info.id).to eq(id)
      expect(info.run_id).to eq(handle.first_execution_run_id)
      expect(info).to be_completed
      expect(info.status).to eq(Temporal::Workflow::ExecutionStatus::COMPLETED)
      expect(Time.now - info.start_time).to be < 5
      expect(Time.now - info.close_time).to be < 5
      expect(Time.now - info.execution_time).to be < 5
    end
  end

  describe 'fetching a workflow result' do
    it 'raises if a workflow fails' do
      input = { actions: [{ error: { message: 'test return value' } }] }
      handle = subject.start_workflow(workflow, input, id: id, task_queue: task_queue)

      expect { handle.result }.to raise_error do |error|
        expect(error).to be_a(Temporal::Error::WorkflowFailure)
        expect(error.cause).to be_a(Temporal::Error::ApplicationError)
        expect(error.cause.message).to eq('test return value')
      end
    end

    it 'follows runs when workflow was continued as new' do
      input = { actions: [
        { continue_as_new: { while_above_zero: 1 } },
        { result: { run_id: true } },
      ] }
      handle = subject.start_workflow(workflow, input, id: id, task_queue: task_queue)
      final_run_id = handle.result

      expect(final_run_id).not_to be_empty
      expect(handle.run_id).not_to eq(final_run_id)

      # Calling without following runs raises as expected
      expect do
        handle.result(follow_runs: false)
      end.to raise_error(Temporal::Error, 'Workflow execution continued as new')
    end
  end

  describe 'querying a workflow' do
    it 'returns query result' do
      input = { actions: [{ query_handler: { name: 'test query' } }] }
      handle = subject.start_workflow(workflow, input, id: id, task_queue: task_queue)
      handle.result

      expect(handle.query('test query', 'test query arg')).to eq('test query arg')
    end

    it 'raises when query is unsupported' do
      input = { actions: [{ query_handler: { name: 'test query' } }] }
      handle = subject.start_workflow(workflow, input, id: id, task_queue: task_queue)
      handle.result

      expect do
        handle.query('other test query', 'test query arg')
      end.to raise_error(Temporal::Error::UnsupportedQuery, 'Unsupported query: other test query')
    end
  end

  describe 'signalling a workflow' do
    it 'sends a signal' do
      input = { action_signal: 'test-signal' }
      handle = subject.start_workflow(workflow, input, id: id, task_queue: task_queue)

      # Empty hash as the last arg is required in Ruby 2.7 to distinguish hash argument from kwargs
      handle.signal('test-signal', { result: { value: 'test signal arg' } }, **{})

      expect(handle.result).to eq('test signal arg')
    end
  end

  describe 'cancelling a workflow' do
    it 'successfully cancels a workflow' do
      input = { actions: [{ sleep: { millis: 15_000 } }] }
      handle = subject.start_workflow(workflow, input, id: id, task_queue: task_queue)
      handle.cancel

      expect { handle.result }.to raise_error do |error|
        expect(error).to be_a(Temporal::Error::WorkflowFailure)
        expect(error.cause).to be_a(Temporal::Error::CancelledError)
        expect(error.cause.message).to eq('Workflow execution cancelled')
      end
    end
  end

  describe 'terminating a workflow' do
    it 'successfully cancels a workflow' do
      input = { actions: [{ sleep: { millis: 15_000 } }] }
      handle = subject.start_workflow(workflow, input, id: id, task_queue: task_queue)
      handle.terminate('test reason')

      expect { handle.result }.to raise_error do |error|
        expect(error).to be_a(Temporal::Error::WorkflowFailure)
        expect(error.cause).to be_a(Temporal::Error::TerminatedError)
        expect(error.cause.message).to eq('test reason')
      end
    end
  end

  describe 'using interceptor' do
    subject { described_class.new(connection, namespace, interceptors: [interceptor]) }

    let(:interceptor) { TestInterceptor.new }

    it 'calls interceptor' do
      input = { actions: [
        { query_handler: { name: 'test query' } },
        { signal: { name: 'test signal' } },
      ] }
      handle = subject.start_workflow(workflow, input, id: id, task_queue: task_queue)

      handle.query('test query', 'test query arg')
      handle.signal('test signal')
      handle.result
      handle.cancel
      handle.describe
      # TODO: Wrap this error in a Temporal::Error
      expect { handle.terminate }.to raise_error(Temporal::Bridge::Error)

      expect(interceptor.results.length).to eq(6)
      expect(interceptor.results[0]).to eq([:start_workflow, workflow])
      expect(interceptor.results[1]).to eq([:query_workflow, 'test query'])
      expect(interceptor.results[2]).to eq([:signal_workflow, 'test signal'])
      expect(interceptor.results[3]).to eq([:cancel_workflow, handle.id])
      expect(interceptor.results[4]).to eq([:describe_workflow, handle.id])
      expect(interceptor.results[5]).to eq([:terminate_workflow, handle.id])
    end
  end
end
