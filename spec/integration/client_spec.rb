require 'securerandom'
require 'temporal/client'
require 'temporal/connection'
require 'temporal/interceptor/client'

describe Temporal::Client do
  SUPPORT_PATH = 'spec/support'.freeze
  PORT = 5555
  TASK_QUEUE = 'test-client'.freeze
  NAMESPACE = 'ruby-samples'.freeze
  URL = "localhost:#{PORT}".freeze

  subject { described_class.new(connection, NAMESPACE) }

  let(:connection) { Temporal::Connection.new("http://#{URL}") }
  let(:id) { SecureRandom.uuid }
  let(:workflow) { 'kitchen_sink' }

  before(:all) do
    @server_pid = fork { exec("#{SUPPORT_PATH}/go_server/main #{PORT} #{NAMESPACE}") }
    sleep(1) # wait for the server to boot up

    @worker_pid = fork { exec("#{SUPPORT_PATH}/go_worker/main #{URL} #{NAMESPACE} #{TASK_QUEUE}") }
    sleep(1) # wait for the worker to boot up
  end

  after(:all) do
    Process.kill('INT', @worker_pid)
    Process.wait(@worker_pid)
    Process.kill('INT', @server_pid)
    Process.wait(@server_pid)
  end

  class IDSwapInterceptor < Temporal::Interceptor::Client
    def initialize(new_id)
      @new_id = new_id
    end

    def start_workflow(input)
      input.id = @new_id
      super
    end
  end

  def actions(*commands)
    { actions: Array.new(commands) }
  end

  def result(value)
    { result: { value: value } }
  end

  def signal(name)
    { signal: { name: name } }
  end

  def error(message, details)
    { signal: { message: message, details: details } }
  end

  def sleep1(time)
    { sleep: { millis: time * 1000 }}
  end

  def query_handler(name)
    { query_handler: { name: name } }
  end

  describe 'start workflow' do
    it 'runs a workflow and waits for a result' do
      input = actions(result('test return value'))
      handle = subject.start_workflow(workflow, input, id: id, task_queue: TASK_QUEUE)

      expect(handle.result).to eq('test return value')
    end

    it 'respects ID reuse policy' do
      input = actions(result('test return value'))
      handle = subject.start_workflow(workflow, input, id: id, task_queue: TASK_QUEUE)

      expect(handle.result).to eq('test return value')

      # Run with REJECT_DUPLICATE expecting a rejection
      input = actions(result('test return value 2'))
      handle = subject.start_workflow(
        workflow,
        input,
        id: id,
        task_queue: TASK_QUEUE,
        id_reuse_policy: Temporal::Workflow::IDReusePolicy::REJECT_DUPLICATE
      )

      expect { handle.result }.to raise_error(Temporal::Error)

      # Run with a default policy again expecting it to succeed
      input = actions(result('test return value 3'))
      handle = subject.start_workflow(workflow, input, id: id, task_queue: TASK_QUEUE)

      expect(handle.result).to eq('test return value 3')
    end

    it 'starts a workflow with a signal' do
      input = actions(signal('my-signal'))
      handle = subject.start_workflow(
        workflow,
        input,
        id: id,
        task_queue: TASK_QUEUE,
        start_signal: 'my-signal',
        start_signal_args: [result('some signal arg')]
      )

      expect(handle.result).to eq('some signal arg')
    end

    it 'works with an interceptor' do
      new_id = SecureRandom.uuid
      interceptor = IDSwapInterceptor.new(new_id)
      client = described_class.new(connection, NAMESPACE, interceptors: [interceptor])
      input = actions(result('test return value'))
      handle = client.start_workflow(workflow, input, id: id, task_queue: TASK_QUEUE)

      expect(handle.id).to eq(new_id)
      expect(handle.result).to eq('test return value')
    end
  end

  describe 'describe workflow' do
    it 'successfully cancels a workflow' do
      input = actions(result('some result value'))
      handle = subject.start_workflow(workflow, input, id: id, task_queue: TASK_QUEUE)

      expect(handle.result).to eq('some result value')

      info = handle.describe

      expect(info.workflow).to eq(workflow)
      expect(info.task_queue).to eq(TASK_QUEUE)
      expect(info.id).to eq(id)
      expect(info.run_id).to eq(handle.run_id)
      expect(info).to be_completed
      expect(info.status).to eq(Temporal::Workflow::ExecutionStatus::COMPLETED)
      expect(Time.now - info.start_time).to be < 5
      expect(Time.now - info.close_time).to be < 5
      expect(Time.now - info.execution_time).to be < 5
    end
  end

  describe 'workflow result' do
    it 'raises if a workflow fails' do
      input = actions(error('some error', 'details'))
      handle = subject.start_workflow(workflow, input, id: id, task_queue: TASK_QUEUE)

      expect { handle.result }.to raise_error(Temporal::Error)
    end
  end

  describe 'query workflow' do
    it 'returns query result' do
      input = actions(query_handler('some query'))
      handle = subject.start_workflow(workflow, input, id: id, task_queue: TASK_QUEUE)
      handle.result

      expect(handle.query('some query', 'some query arg')).to eq('some query arg')
    end

    it 'raises when query is unsupported' do
      input = actions(query_handler('some query'))
      handle = subject.start_workflow(workflow, input, id: id, task_queue: TASK_QUEUE)
      handle.result

      # TODO: Change this to a wrapped error later
      expect do
        handle.query('some other query', 'some query arg')
      end.to raise_error(Temporal::Bridge::Error)
    end
  end

  describe 'cancel workflow' do
    it 'successfully cancels a workflow' do
      input = actions(sleep1(50))
      handle = subject.start_workflow(workflow, input, id: id, task_queue: TASK_QUEUE)
      handle.cancel

      expect { handle.result }.to raise_error(Temporal::Error, 'Workflow execution cancelled')
    end
  end

  describe 'terminate workflow' do
    it 'successfully cancels a workflow' do
      input = actions(sleep1(50))
      handle = subject.start_workflow(workflow, input, id: id, task_queue: TASK_QUEUE)
      handle.terminate

      expect { handle.result }.to raise_error(Temporal::Error, 'Workflow execution terminated')
    end
  end
end
