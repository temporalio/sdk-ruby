require 'securerandom'
require 'temporalio/client'
require 'temporalio/client/implementation'
require 'temporalio/client/workflow_handle'
require 'temporalio/connection'
require 'temporalio/data_converter'
require 'temporalio/retry_policy'

describe Temporalio::Client do
  subject { described_class.new(connection, namespace, interceptors: interceptors) }

  let(:connection) { instance_double(Temporalio::Connection) }
  let(:namespace) { 'test-namespace' }
  let(:interceptors) { [] }
  let(:client_impl) { instance_double(Temporalio::Client::Implementation) }
  let(:id) { SecureRandom.uuid }
  let(:run_id) { SecureRandom.uuid }
  let(:first_execution_run_id) { SecureRandom.uuid }

  before do
    allow(Temporalio::Client::Implementation)
      .to receive(:new)
      .with(connection, namespace, an_instance_of(Temporalio::DataConverter), interceptors)
      .and_return(client_impl)
  end

  describe '#start_workflow' do
    let(:handle) do
      Temporalio::Client::WorkflowHandle.new(
        client_impl,
        id,
        result_run_id: run_id,
        first_execution_run_id: first_execution_run_id,
      )
    end

    before { allow(client_impl).to receive(:start_workflow).and_return(handle) }

    it 'calls the client implementation with mostly default arguments' do
      result = subject.start_workflow(
        'TestWorkflow',
        1, 2, 3,
        id: id,
        task_queue: 'test-queue',
      )

      expect(result).to eq(handle)
      expect(client_impl).to have_received(:start_workflow) do |input|
        expect(input).to be_a(Temporalio::Interceptor::Client::StartWorkflowInput)
        expect(input.workflow).to eq('TestWorkflow')
        expect(input.id).to eq(id)
        expect(input.args).to eq([1, 2, 3])
        expect(input.task_queue).to eq('test-queue')
        expect(input.execution_timeout).to eq(nil)
        expect(input.run_timeout).to eq(nil)
        expect(input.task_timeout).to eq(nil)
        expect(input.id_reuse_policy).to eq(Temporalio::Workflow::IDReusePolicy::ALLOW_DUPLICATE)
        expect(input.retry_policy).to eq(nil)
        expect(input.cron_schedule).to eq('')
        expect(input.memo).to eq(nil)
        expect(input.search_attributes).to eq(nil)
        expect(input.headers).to eq({})
        expect(input.start_signal).to eq(nil)
        expect(input.start_signal_args).to eq([])
        expect(input.rpc_metadata).to eq({})
        expect(input.rpc_timeout).to eq(nil)
      end
    end

    it 'calls the client implementation with custom arguments' do
      retry_policy = Temporalio::RetryPolicy.new(initial_interval: 5, backoff: 10)

      result = subject.start_workflow(
        'TestWorkflow',
        1, 2, 3,
        id: id,
        task_queue: 'test-queue',
        execution_timeout: 60_000,
        run_timeout: 30_000,
        task_timeout: 5_000,
        id_reuse_policy: Temporalio::Workflow::IDReusePolicy::REJECT_DUPLICATE,
        retry_policy: retry_policy,
        cron_schedule: '* * * * 1',
        memo: { 'memo' => 'test' },
        search_attributes: { 'search_attributes' => 'test' },
        start_signal: 'test-signal',
        start_signal_args: [42],
        rpc_metadata: { 'foo' => 'bar' },
        rpc_timeout: 5_000,
      )

      expect(result).to eq(handle)
      expect(client_impl).to have_received(:start_workflow) do |input|
        expect(input).to be_a(Temporalio::Interceptor::Client::StartWorkflowInput)
        expect(input.workflow).to eq('TestWorkflow')
        expect(input.id).to eq(id)
        expect(input.args).to eq([1, 2, 3])
        expect(input.task_queue).to eq('test-queue')
        expect(input.execution_timeout).to eq(60_000)
        expect(input.run_timeout).to eq(30_000)
        expect(input.task_timeout).to eq(5_000)
        expect(input.id_reuse_policy).to eq(Temporalio::Workflow::IDReusePolicy::REJECT_DUPLICATE)
        expect(input.retry_policy).to eq(retry_policy)
        expect(input.cron_schedule).to eq('* * * * 1')
        expect(input.memo).to eq({ 'memo' => 'test' })
        expect(input.search_attributes).to eq({ 'search_attributes' => 'test' })
        expect(input.headers).to eq({})
        expect(input.start_signal).to eq('test-signal')
        expect(input.start_signal_args).to eq([42])
        expect(input.rpc_metadata).to eq({ 'foo' => 'bar' })
        expect(input.rpc_timeout).to eq(5_000)
      end
    end
  end

  describe '#workflow_handle' do
    it 'returns a new workflow handle' do
      handle = subject.workflow_handle(id)

      expect(handle).to be_a(Temporalio::Client::WorkflowHandle)
      expect(handle.id).to eq(id)
      expect(handle.run_id).to eq(nil)
      expect(handle.result_run_id).to eq(nil)
      expect(handle.first_execution_run_id).to eq(nil)
    end

    it 'returns a new workflow handle with run_id specified' do
      handle = subject.workflow_handle(id, run_id: run_id)

      expect(handle).to be_a(Temporalio::Client::WorkflowHandle)
      expect(handle.id).to eq(id)
      expect(handle.run_id).to eq(run_id)
      expect(handle.result_run_id).to eq(run_id)
      expect(handle.first_execution_run_id).to eq(nil)
    end

    it 'returns a new workflow handle with first_execution_run_id specified' do
      handle = subject.workflow_handle(id, first_execution_run_id: first_execution_run_id)

      expect(handle).to be_a(Temporalio::Client::WorkflowHandle)
      expect(handle.id).to eq(id)
      expect(handle.run_id).to eq(nil)
      expect(handle.result_run_id).to eq(nil)
      expect(handle.first_execution_run_id).to eq(first_execution_run_id)
    end

    it 'returns a new workflow handle with both run_id and first_execution_run_id' do
      handle = subject.workflow_handle(id, run_id: run_id, first_execution_run_id: first_execution_run_id)

      expect(handle).to be_a(Temporalio::Client::WorkflowHandle)
      expect(handle.id).to eq(id)
      expect(handle.run_id).to eq(run_id)
      expect(handle.result_run_id).to eq(run_id)
      expect(handle.first_execution_run_id).to eq(first_execution_run_id)
    end
  end
end
