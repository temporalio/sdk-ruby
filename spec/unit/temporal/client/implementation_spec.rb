require 'securerandom'
require 'support/helpers/test_capture_interceptor'
require 'temporal/api/workflowservice/v1/request_response_pb'
require 'temporal/client/implementation'
require 'temporal/client/workflow_handle'
require 'temporal/connection'
require 'temporal/converter'
require 'temporal/errors'

describe Temporal::Client::Implementation do
  subject { described_class.new(connection, namespace, converter, interceptors) }

  let(:connection) { instance_double(Temporal::Connection) }
  let(:namespace) { 'test-namespace' }
  let(:converter) { Temporal::Converter.new }
  let(:interceptors) { [] }
  let(:id) { SecureRandom.uuid }
  let(:run_id) { SecureRandom.uuid }

  describe '#start_workflow' do
    let(:input) do
      Temporal::Interceptor::Client::StartWorkflowInput.new(
        workflow: 'TestWorkflow',
        id: id,
        args: [1, 2, 3],
        task_queue: 'test-queue',
        execution_timeout: 60_000,
        run_timeout: 30_000,
        task_timeout: 5_000,
        id_reuse_policy: Temporal::Workflow::IDReusePolicy::REJECT_DUPLICATE,
        retry_policy: nil,
        cron_schedule: '* * * * 1',
        memo: nil,
        search_attributes: nil,
        headers: {},
        start_signal: nil,
        start_signal_args: nil,
      )
    end

    before do
      allow(connection)
        .to receive(:start_workflow_execution)
        .and_return(
          Temporal::Api::WorkflowService::V1::StartWorkflowExecutionResponse.new(
            run_id: run_id,
          )
        )

      allow(connection)
        .to receive(:signal_with_start_workflow_execution)
        .and_return(
          Temporal::Api::WorkflowService::V1::SignalWithStartWorkflowExecutionResponse.new(
            run_id: run_id,
          )
        )
    end

    it 'calls the RPC method' do
      subject.start_workflow(input)

      expect(connection).to have_received(:start_workflow_execution) do |request|
        expect(request).to be_a(Temporal::Api::WorkflowService::V1::StartWorkflowExecutionRequest)
        expect(request.identity).to include("(Ruby SDK v#{Temporal::VERSION})")
        expect(request.request_id).to be_a(String)
        expect(request.workflow_type.name).to eq('TestWorkflow')
        expect(request.workflow_id).to eq(id)
        expect(request.task_queue.name).to eq('test-queue')
        expect(request.input.payloads[0].data).to eq('1')
        expect(request.input.payloads[1].data).to eq('2')
        expect(request.input.payloads[2].data).to eq('3')
        expect(request.workflow_execution_timeout.seconds).to eq(60_000)
        expect(request.workflow_run_timeout.seconds).to eq(30_000)
        expect(request.workflow_task_timeout.seconds).to eq(5_000)
        expect(request.workflow_id_reuse_policy).to eq(:WORKFLOW_ID_REUSE_POLICY_REJECT_DUPLICATE)
        expect(request.retry_policy).to eq(nil)
        expect(request.cron_schedule).to eq('* * * * 1')
        expect(request.memo).to eq(nil)
        expect(request.search_attributes).to eq(nil)
        expect(request.header).to eq(nil)
      end
    end

    it 'returns a workflow handle' do
      handle = subject.start_workflow(input)

      expect(handle).to be_a(Temporal::Client::WorkflowHandle)
      expect(handle.id).to eq(id)
      expect(handle.run_id).to eq(nil)
      expect(handle.result_run_id).to eq(run_id)
      expect(handle.first_execution_run_id).to eq(run_id)
    end

    context 'with memo' do
      before { input.memo = { 'memo' => 'test' } }

      it 'includes a serialized memo' do
        subject.start_workflow(input)

        expect(connection).to have_received(:start_workflow_execution) do |request|
          expect(request.memo.fields['memo'].data).to eq('"test"')
        end
      end
    end

    context 'with search_attributes' do
      before { input.search_attributes = { 'search_attributes' => 'test' } }

      it 'includes serialized search_attributes' do
        subject.start_workflow(input)

        expect(connection).to have_received(:start_workflow_execution) do |request|
          expect(request.search_attributes.indexed_fields['search_attributes'].data).to eq('"test"')
        end
      end
    end

    context 'with header' do
      before { input.headers = { 'header' => 'test' } }

      it 'includes a serialized header' do
        subject.start_workflow(input)

        expect(connection).to have_received(:start_workflow_execution) do |request|
          expect(request.header.fields['header'].data).to eq('"test"')
        end
      end
    end

    context 'with start signal' do
      before do
        input.start_signal = 'test-signal'
        input.start_signal_args = [1, 2, 3]
      end

      it 'includes a serialized header' do
        subject.start_workflow(input)

        expect(connection).to have_received(:signal_with_start_workflow_execution) do |request|
          expect(request)
            .to be_a(Temporal::Api::WorkflowService::V1::SignalWithStartWorkflowExecutionRequest)
          expect(request.signal_name).to eq('test-signal')
          expect(request.signal_input.payloads[0].data).to eq('1')
          expect(request.signal_input.payloads[1].data).to eq('2')
          expect(request.signal_input.payloads[2].data).to eq('3')
        end
      end

      it 'returns a workflow handle without first_execution_run_id' do
        handle = subject.start_workflow(input)

        expect(handle).to be_a(Temporal::Client::WorkflowHandle)
        expect(handle.id).to eq(id)
        expect(handle.run_id).to eq(nil)
        expect(handle.result_run_id).to eq(run_id)
        expect(handle.first_execution_run_id).to eq(nil)
      end
    end

    context 'with interceptors' do
      let(:interceptors) { [interceptor] }
      let(:interceptor) { Helpers::TestCaptureInterceptor.new }

      it 'calls the interceptor' do
        subject.start_workflow(input)

        expect(interceptor.called_methods).to eq([:start_workflow])
      end
    end

    context 'when Workflow already exists' do
      before do
        allow(connection)
          .to receive(:start_workflow_execution)
          .and_raise(Temporal::Bridge::Error, 'status: AlreadyExists')
      end

      it 'raises Temporal::Error' do
        expect do
          subject.start_workflow(input)
        end.to raise_error(Temporal::Error, 'Workflow already exists')
      end
    end

    context 'when RPC call fails' do
      before do
        allow(connection)
          .to receive(:start_workflow_execution)
          .and_raise(Temporal::Bridge::Error, 'Some other error')
      end

      it 're-raises RPC error' do
        expect do
          subject.start_workflow(input)
        end.to raise_error(Temporal::Bridge::Error, 'Some other error')
      end
    end
  end

  describe '#describe_workflow' do
    let(:input) do
      Temporal::Interceptor::Client::DescribeWorkflowInput.new(
        id: id,
        run_id: run_id,
      )
    end
    let(:time_now) { Time.now }

    before do
      payload = Temporal::Api::Common::V1::Payload.new(
        metadata: { 'encoding' => 'json/plain' },
        data: '"test"',
      )

      allow(connection)
        .to receive(:describe_workflow_execution)
        .and_return(
          Temporal::Api::WorkflowService::V1::DescribeWorkflowExecutionResponse.new(
            workflow_execution_info: {
              execution: { workflow_id: id, run_id: run_id },
              type: { name: 'TestWorkflow' },
              task_queue: 'test-queue',
              start_time: { nanos: time_now.nsec, seconds: time_now.to_i },
              close_time: { nanos: time_now.nsec, seconds: time_now.to_i },
              status: :WORKFLOW_EXECUTION_STATUS_COMPLETED,
              history_length: 4,
              parent_execution: { workflow_id: 'parent-id', run_id: 'parent-run-id' },
              execution_time: { nanos: time_now.nsec, seconds: time_now.to_i },
              memo: { fields: { 'memo' => payload } },
              search_attributes: { indexed_fields: { 'attrs' => payload } },
            },
          )
        )
    end

    it 'calls the RPC method' do
      subject.describe_workflow(input)

      expect(connection).to have_received(:describe_workflow_execution) do |request|
        expect(request).to be_a(Temporal::Api::WorkflowService::V1::DescribeWorkflowExecutionRequest)
        expect(request.namespace).to eq(namespace)
        expect(request.execution.workflow_id).to eq(id)
        expect(request.execution.run_id).to eq(run_id)
      end
    end

    it 'returns workflow execution info' do
      info = subject.describe_workflow(input)

      expect(info).to be_a(Temporal::Workflow::ExecutionInfo)
      expect(info.raw).to be_a(Temporal::Api::WorkflowService::V1::DescribeWorkflowExecutionResponse)
      expect(info.workflow).to eq('TestWorkflow')
      expect(info.id).to eq(id)
      expect(info.run_id).to eq(run_id)
      expect(info.task_queue).to eq('test-queue')
      expect(info.status).to eq(Temporal::Workflow::ExecutionStatus::COMPLETED)
      expect(info.parent_id).to eq('parent-id')
      expect(info.parent_run_id).to eq('parent-run-id')
      expect(info.start_time).to eq(time_now)
      expect(info.close_time).to eq(time_now)
      expect(info.execution_time).to eq(time_now)
      expect(info.history_length).to eq(4)
      expect(info.memo).to eq({ 'memo' => 'test' })
      expect(info.search_attributes).to eq({ 'attrs' => 'test' })
    end

    context 'with interceptors' do
      let(:interceptors) { [interceptor] }
      let(:interceptor) { Helpers::TestCaptureInterceptor.new }

      it 'calls the interceptor' do
        subject.describe_workflow(input)

        expect(interceptor.called_methods).to eq([:describe_workflow])
      end
    end
  end

  describe '#query_workflow' do
    let(:input) do
      Temporal::Interceptor::Client::QueryWorkflowInput.new(
        id: id,
        run_id: run_id,
        query: 'test-query',
        args: [1, 2, 3],
        reject_condition: Temporal::Workflow::QueryRejectCondition::NOT_OPEN,
        headers: {},
      )
    end

    before do
      payload = Temporal::Api::Common::V1::Payload.new(
        metadata: { 'encoding' => 'json/plain' },
        data: '"test"',
      )

      allow(connection)
        .to receive(:query_workflow)
        .and_return(
          Temporal::Api::WorkflowService::V1::QueryWorkflowResponse.new(
            query_result: { payloads: [payload] },
          )
        )
    end

    it 'calls the RPC method' do
      subject.query_workflow(input)

      expect(connection).to have_received(:query_workflow) do |request|
        expect(request).to be_a(Temporal::Api::WorkflowService::V1::QueryWorkflowRequest)
        expect(request.namespace).to eq(namespace)
        expect(request.execution.workflow_id).to eq(id)
        expect(request.execution.run_id).to eq(run_id)
        expect(request.query.query_type).to eq('test-query')
        expect(request.query.query_args.payloads[0].data).to eq('1')
        expect(request.query.query_args.payloads[1].data).to eq('2')
        expect(request.query.query_args.payloads[2].data).to eq('3')
        expect(request.query.header).to eq(nil)
        expect(request.query_reject_condition).to eq(:QUERY_REJECT_CONDITION_NOT_OPEN)
      end
    end

    it 'returns query result' do
      expect(subject.query_workflow(input)).to eq('test')
    end

    context 'with header' do
      before { input.headers = { 'header' => 'test' } }

      it 'includes a serialized header' do
        subject.query_workflow(input)

        expect(connection).to have_received(:query_workflow) do |request|
          expect(request.query.header.fields['header'].data).to eq('"test"')
        end
      end
    end

    context 'with interceptors' do
      let(:interceptors) { [interceptor] }
      let(:interceptor) { Helpers::TestCaptureInterceptor.new }

      it 'calls the interceptor' do
        subject.query_workflow(input)

        expect(interceptor.called_methods).to eq([:query_workflow])
      end
    end
  end

  describe '#signal_workflow' do
    let(:input) do
      Temporal::Interceptor::Client::SignalWorkflowInput.new(
        id: id,
        run_id: run_id,
        signal: 'test-signal',
        args: [1, 2, 3],
        headers: {},
      )
    end

    before do
      allow(connection)
        .to receive(:signal_workflow_execution)
        .and_return(Temporal::Api::WorkflowService::V1::SignalWorkflowExecutionResponse.new)
    end

    it 'calls the RPC method' do
      subject.signal_workflow(input)

      expect(connection).to have_received(:signal_workflow_execution) do |request|
        expect(request).to be_a(Temporal::Api::WorkflowService::V1::SignalWorkflowExecutionRequest)
        expect(request.namespace).to eq(namespace)
        expect(request.workflow_execution.workflow_id).to eq(id)
        expect(request.workflow_execution.run_id).to eq(run_id)
        expect(request.signal_name).to eq('test-signal')
        expect(request.input.payloads[0].data).to eq('1')
        expect(request.input.payloads[1].data).to eq('2')
        expect(request.input.payloads[2].data).to eq('3')
        expect(request.identity).to include("(Ruby SDK v#{Temporal::VERSION})")
        expect(request.request_id).to be_a(String)
        expect(request.control).to eq('')
        expect(request.header).to eq(nil)
      end
    end

    it 'returns nil' do
      expect(subject.signal_workflow(input)).to eq(nil)
    end

    context 'with header' do
      before { input.headers = { 'header' => 'test' } }

      it 'includes a serialized header' do
        subject.signal_workflow(input)

        expect(connection).to have_received(:signal_workflow_execution) do |request|
          expect(request.header.fields['header'].data).to eq('"test"')
        end
      end
    end

    context 'with interceptors' do
      let(:interceptors) { [interceptor] }
      let(:interceptor) { Helpers::TestCaptureInterceptor.new }

      it 'calls the interceptor' do
        subject.signal_workflow(input)

        expect(interceptor.called_methods).to eq([:signal_workflow])
      end
    end
  end

  describe '#cancel_workflow' do
    let(:input) do
      Temporal::Interceptor::Client::CancelWorkflowInput.new(
        id: id,
        run_id: run_id,
        first_execution_run_id: run_id,
        reason: 'test reason',
      )
    end

    before do
      allow(connection)
        .to receive(:request_cancel_workflow_execution)
        .and_return(Temporal::Api::WorkflowService::V1::RequestCancelWorkflowExecutionResponse.new)
    end

    it 'calls the RPC method' do
      subject.cancel_workflow(input)

      expect(connection).to have_received(:request_cancel_workflow_execution) do |request|
        expect(request).to be_a(Temporal::Api::WorkflowService::V1::RequestCancelWorkflowExecutionRequest)
        expect(request.namespace).to eq(namespace)
        expect(request.workflow_execution.workflow_id).to eq(id)
        expect(request.workflow_execution.run_id).to eq(run_id)
        expect(request.identity).to include("(Ruby SDK v#{Temporal::VERSION})")
        expect(request.request_id).to be_a(String)
        expect(request.first_execution_run_id).to eq(run_id)
        expect(request.reason).to eq('test reason')
      end
    end

    it 'returns nil' do
      expect(subject.cancel_workflow(input)).to eq(nil)
    end

    context 'with interceptors' do
      let(:interceptors) { [interceptor] }
      let(:interceptor) { Helpers::TestCaptureInterceptor.new }

      it 'calls the interceptor' do
        subject.cancel_workflow(input)

        expect(interceptor.called_methods).to eq([:cancel_workflow])
      end
    end
  end

  describe '#terminate_workflow' do
    let(:input) do
      Temporal::Interceptor::Client::TerminateWorkflowInput.new(
        id: id,
        run_id: run_id,
        first_execution_run_id: run_id,
        reason: 'test reason',
      )
    end

    before do
      allow(connection)
        .to receive(:terminate_workflow_execution)
        .and_return(Temporal::Api::WorkflowService::V1::TerminateWorkflowExecutionResponse.new)
    end

    it 'calls the RPC method' do
      subject.terminate_workflow(input)

      expect(connection).to have_received(:terminate_workflow_execution) do |request|
        expect(request)
          .to be_a(Temporal::Api::WorkflowService::V1::TerminateWorkflowExecutionRequest)
        expect(request.namespace).to eq(namespace)
        expect(request.workflow_execution.workflow_id).to eq(id)
        expect(request.workflow_execution.run_id).to eq(run_id)
        expect(request.reason).to eq('test reason')
        expect(request.details).to eq(nil)
        expect(request.identity).to include("(Ruby SDK v#{Temporal::VERSION})")
        expect(request.first_execution_run_id).to eq(run_id)
      end
    end

    it 'returns nil' do
      expect(subject.terminate_workflow(input)).to eq(nil)
    end

    context 'with details' do
      before { input.args = [1, 2, 3] }

      it 'includes a serialized header' do
        subject.terminate_workflow(input)

        expect(connection).to have_received(:terminate_workflow_execution) do |request|
          expect(request.details.payloads[0].data).to eq('1')
          expect(request.details.payloads[1].data).to eq('2')
          expect(request.details.payloads[2].data).to eq('3')
        end
      end
    end

    context 'with interceptors' do
      let(:interceptors) { [interceptor] }
      let(:interceptor) { Helpers::TestCaptureInterceptor.new }

      it 'calls the interceptor' do
        subject.terminate_workflow(input)

        expect(interceptor.called_methods).to eq([:terminate_workflow])
      end
    end
  end
end