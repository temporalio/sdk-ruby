require 'securerandom'
require 'support/helpers/test_capture_interceptor'
require 'temporal/api/workflowservice/v1/request_response_pb'
require 'temporalio/client/implementation'
require 'temporalio/client/workflow_handle'
require 'temporalio/connection'
require 'temporalio/data_converter'
require 'temporalio/errors'
require 'temporalio/failure_converter'
require 'temporalio/payload_converter'

describe Temporalio::Client::Implementation do
  subject { described_class.new(connection, namespace, converter, interceptors) }

  let(:connection) { instance_double(Temporalio::Connection) }
  let(:namespace) { 'test-namespace' }
  let(:converter) do
    Temporalio::DataConverter.new(
      payload_converter: Temporalio::PayloadConverter::DEFAULT,
      payload_codecs: [],
      failure_converter: Temporalio::FailureConverter::DEFAULT,
    )
  end
  let(:interceptors) { [] }
  let(:id) { SecureRandom.uuid }
  let(:run_id) { SecureRandom.uuid }
  let(:payload_proto) do
    Temporalio::Api::Common::V1::Payload.new(
      metadata: { 'encoding' => 'json/plain' },
      data: '"test"',
    )
  end
  let(:metadata) { { 'foo' => 'bar' } }
  let(:timeout) { 5_000 }

  describe '#start_workflow' do
    let(:input) do
      Temporalio::Interceptor::Client::StartWorkflowInput.new(
        workflow: 'TestWorkflow',
        id: id,
        args: [1, 2, 3],
        task_queue: 'test-queue',
        execution_timeout: 60_000,
        run_timeout: 30_000,
        task_timeout: 5_000,
        id_reuse_policy: Temporalio::Workflow::IDReusePolicy::REJECT_DUPLICATE,
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
          Temporalio::Api::WorkflowService::V1::StartWorkflowExecutionResponse.new(
            run_id: run_id,
          )
        )

      allow(connection)
        .to receive(:signal_with_start_workflow_execution)
        .and_return(
          Temporalio::Api::WorkflowService::V1::SignalWithStartWorkflowExecutionResponse.new(
            run_id: run_id,
          )
        )
    end

    it 'calls the RPC method' do
      subject.start_workflow(input)

      expect(connection).to have_received(:start_workflow_execution) do |request|
        expect(request).to be_a(Temporalio::Api::WorkflowService::V1::StartWorkflowExecutionRequest)
        expect(request.identity).to include("(Ruby SDK v#{Temporalio::VERSION})")
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

      expect(handle).to be_a(Temporalio::Client::WorkflowHandle)
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

    context 'with RPC params' do
      before do
        input.rpc_metadata = metadata
        input.rpc_timeout = timeout
      end

      it 'passes RPC params to the connection' do
        subject.start_workflow(input)

        expect(connection)
          .to have_received(:start_workflow_execution)
          .with(anything, metadata: metadata, timeout: timeout)
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
            .to be_a(Temporalio::Api::WorkflowService::V1::SignalWithStartWorkflowExecutionRequest)
          expect(request.signal_name).to eq('test-signal')
          expect(request.signal_input.payloads[0].data).to eq('1')
          expect(request.signal_input.payloads[1].data).to eq('2')
          expect(request.signal_input.payloads[2].data).to eq('3')
        end
      end

      it 'returns a workflow handle without first_execution_run_id' do
        handle = subject.start_workflow(input)

        expect(handle).to be_a(Temporalio::Client::WorkflowHandle)
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
          .and_raise(Temporalio::Bridge::Error, 'status: AlreadyExists')
      end

      it 'raises Temporalio::Error' do
        expect do
          subject.start_workflow(input)
        end.to raise_error(Temporalio::Error::WorkflowExecutionAlreadyStarted, 'Workflow execution already started')
      end
    end

    context 'when RPC call fails' do
      before do
        allow(connection)
          .to receive(:start_workflow_execution)
          .and_raise(Temporalio::Bridge::Error, 'Some other error')
      end

      it 're-raises RPC error' do
        expect do
          subject.start_workflow(input)
        end.to raise_error(Temporalio::Bridge::Error, 'Some other error')
      end
    end
  end

  describe '#describe_workflow' do
    let(:input) do
      Temporalio::Interceptor::Client::DescribeWorkflowInput.new(
        id: id,
        run_id: run_id,
      )
    end
    let(:time_now) { Time.now }

    before do
      allow(connection)
        .to receive(:describe_workflow_execution)
        .and_return(
          Temporalio::Api::WorkflowService::V1::DescribeWorkflowExecutionResponse.new(
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
              memo: { fields: { 'memo' => payload_proto } },
              search_attributes: { indexed_fields: { 'attrs' => payload_proto } },
            },
          )
        )
    end

    it 'calls the RPC method' do
      subject.describe_workflow(input)

      expect(connection).to have_received(:describe_workflow_execution) do |request|
        expect(request).to be_a(Temporalio::Api::WorkflowService::V1::DescribeWorkflowExecutionRequest)
        expect(request.namespace).to eq(namespace)
        expect(request.execution.workflow_id).to eq(id)
        expect(request.execution.run_id).to eq(run_id)
      end
    end

    it 'returns workflow execution info' do
      info = subject.describe_workflow(input)

      expect(info).to be_a(Temporalio::Workflow::ExecutionInfo)
      expect(info.raw).to be_a(Temporalio::Api::WorkflowService::V1::DescribeWorkflowExecutionResponse)
      expect(info.workflow).to eq('TestWorkflow')
      expect(info.id).to eq(id)
      expect(info.run_id).to eq(run_id)
      expect(info.task_queue).to eq('test-queue')
      expect(info.status).to eq(Temporalio::Workflow::ExecutionStatus::COMPLETED)
      expect(info.parent_id).to eq('parent-id')
      expect(info.parent_run_id).to eq('parent-run-id')
      expect(info.start_time).to eq(time_now)
      expect(info.close_time).to eq(time_now)
      expect(info.execution_time).to eq(time_now)
      expect(info.history_length).to eq(4)
      expect(info.memo).to eq({ 'memo' => 'test' })
      expect(info.search_attributes).to eq({ 'attrs' => 'test' })
    end

    context 'with RPC params' do
      before do
        input.rpc_metadata = metadata
        input.rpc_timeout = timeout
      end

      it 'passes RPC params to the connection' do
        subject.describe_workflow(input)

        expect(connection)
          .to have_received(:describe_workflow_execution)
          .with(anything, metadata: metadata, timeout: timeout)
      end
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
      Temporalio::Interceptor::Client::QueryWorkflowInput.new(
        id: id,
        run_id: run_id,
        query: 'test-query',
        args: [1, 2, 3],
        reject_condition: Temporalio::Workflow::QueryRejectCondition::NOT_OPEN,
        headers: {},
      )
    end

    before do
      allow(connection)
        .to receive(:query_workflow)
        .and_return(
          Temporalio::Api::WorkflowService::V1::QueryWorkflowResponse.new(
            query_result: { payloads: [payload_proto] },
          )
        )
    end

    it 'calls the RPC method' do
      subject.query_workflow(input)

      expect(connection).to have_received(:query_workflow) do |request|
        expect(request).to be_a(Temporalio::Api::WorkflowService::V1::QueryWorkflowRequest)
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

    context 'when query is rejected' do
      before do
        allow(connection)
          .to receive(:query_workflow)
          .and_return(
            Temporalio::Api::WorkflowService::V1::QueryWorkflowResponse.new(
              query_rejected: { status: :WORKFLOW_EXECUTION_STATUS_COMPLETED },
            )
          )
      end

      it 'raises an error' do
        expect { subject.query_workflow(input) }.to raise_error do |error|
          expect(error).to be_a(Temporalio::Error::QueryRejected)
          expect(error.message).to eq('Query rejected, workflow status: COMPLETED')
          expect(error.status).to eq(Temporalio::Workflow::ExecutionStatus::COMPLETED)
        end
      end
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

    context 'with RPC params' do
      before do
        input.rpc_metadata = metadata
        input.rpc_timeout = timeout
      end

      it 'passes RPC params to the connection' do
        subject.query_workflow(input)

        expect(connection)
          .to have_received(:query_workflow)
          .with(anything, metadata: metadata, timeout: timeout)
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
      Temporalio::Interceptor::Client::SignalWorkflowInput.new(
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
        .and_return(Temporalio::Api::WorkflowService::V1::SignalWorkflowExecutionResponse.new)
    end

    it 'calls the RPC method' do
      subject.signal_workflow(input)

      expect(connection).to have_received(:signal_workflow_execution) do |request|
        expect(request).to be_a(Temporalio::Api::WorkflowService::V1::SignalWorkflowExecutionRequest)
        expect(request.namespace).to eq(namespace)
        expect(request.workflow_execution.workflow_id).to eq(id)
        expect(request.workflow_execution.run_id).to eq(run_id)
        expect(request.signal_name).to eq('test-signal')
        expect(request.input.payloads[0].data).to eq('1')
        expect(request.input.payloads[1].data).to eq('2')
        expect(request.input.payloads[2].data).to eq('3')
        expect(request.identity).to include("(Ruby SDK v#{Temporalio::VERSION})")
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

    context 'with RPC params' do
      before do
        input.rpc_metadata = metadata
        input.rpc_timeout = timeout
      end

      it 'passes RPC params to the connection' do
        subject.signal_workflow(input)

        expect(connection)
          .to have_received(:signal_workflow_execution)
          .with(anything, metadata: metadata, timeout: timeout)
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
      Temporalio::Interceptor::Client::CancelWorkflowInput.new(
        id: id,
        run_id: run_id,
        first_execution_run_id: run_id,
        reason: 'test reason',
      )
    end

    before do
      allow(connection)
        .to receive(:request_cancel_workflow_execution)
        .and_return(Temporalio::Api::WorkflowService::V1::RequestCancelWorkflowExecutionResponse.new)
    end

    it 'calls the RPC method' do
      subject.cancel_workflow(input)

      expect(connection).to have_received(:request_cancel_workflow_execution) do |request|
        expect(request).to be_a(Temporalio::Api::WorkflowService::V1::RequestCancelWorkflowExecutionRequest)
        expect(request.namespace).to eq(namespace)
        expect(request.workflow_execution.workflow_id).to eq(id)
        expect(request.workflow_execution.run_id).to eq(run_id)
        expect(request.identity).to include("(Ruby SDK v#{Temporalio::VERSION})")
        expect(request.request_id).to be_a(String)
        expect(request.first_execution_run_id).to eq(run_id)
        expect(request.reason).to eq('test reason')
      end
    end

    it 'returns nil' do
      expect(subject.cancel_workflow(input)).to eq(nil)
    end

    context 'with RPC params' do
      before do
        input.rpc_metadata = metadata
        input.rpc_timeout = timeout
      end

      it 'passes RPC params to the connection' do
        subject.cancel_workflow(input)

        expect(connection)
          .to have_received(:request_cancel_workflow_execution)
          .with(anything, metadata: metadata, timeout: timeout)
      end
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
      Temporalio::Interceptor::Client::TerminateWorkflowInput.new(
        id: id,
        run_id: run_id,
        first_execution_run_id: run_id,
        reason: 'test reason',
      )
    end

    before do
      allow(connection)
        .to receive(:terminate_workflow_execution)
        .and_return(Temporalio::Api::WorkflowService::V1::TerminateWorkflowExecutionResponse.new)
    end

    it 'calls the RPC method' do
      subject.terminate_workflow(input)

      expect(connection).to have_received(:terminate_workflow_execution) do |request|
        expect(request)
          .to be_a(Temporalio::Api::WorkflowService::V1::TerminateWorkflowExecutionRequest)
        expect(request.namespace).to eq(namespace)
        expect(request.workflow_execution.workflow_id).to eq(id)
        expect(request.workflow_execution.run_id).to eq(run_id)
        expect(request.reason).to eq('test reason')
        expect(request.details).to eq(nil)
        expect(request.identity).to include("(Ruby SDK v#{Temporalio::VERSION})")
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

    context 'with RPC params' do
      before do
        input.rpc_metadata = metadata
        input.rpc_timeout = timeout
      end

      it 'passes RPC params to the connection' do
        subject.terminate_workflow(input)

        expect(connection)
          .to have_received(:terminate_workflow_execution)
          .with(anything, metadata: metadata, timeout: timeout)
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

  describe '#await_workflow_result' do
    let(:failure_proto) do
      Temporalio::Api::Failure::V1::Failure.new(
        message: 'Test error',
        application_failure_info: {
          type: 'ApplicationError',
          non_retryable: true,
          details: { payloads: [payload_proto] },
        }
      )
    end
    let(:new_run_id) { '' }

    before do
      allow(connection)
        .to receive(:get_workflow_execution_history)
        .and_return(
          Temporalio::Api::WorkflowService::V1::GetWorkflowExecutionHistoryResponse.new(
            history: { events: [event_proto] }
          )
        )
    end

    shared_examples 'follow runs' do
      let(:new_run_id) { SecureRandom.uuid }
      let(:completed_event_proto) do
        new_payload = payload_proto.dup
        new_payload.data = '"new test"'

        Temporalio::Api::History::V1::HistoryEvent.new(
          event_type: :EVENT_TYPE_WORKFLOW_EXECUTION_COMPLETED,
          workflow_execution_completed_event_attributes: {
            result: { payloads: [new_payload] },
          }
        )
      end

      before do
        allow(connection)
          .to receive(:get_workflow_execution_history)
          .and_return(
            Temporalio::Api::WorkflowService::V1::GetWorkflowExecutionHistoryResponse.new(
              history: { events: [event_proto] }
            ),
            Temporalio::Api::WorkflowService::V1::GetWorkflowExecutionHistoryResponse.new(
              history: { events: [completed_event_proto] }
            )
          )
      end

      it 'calls RPC twice' do
        result = subject.await_workflow_result(id, run_id, true, metadata, timeout)

        expect(result).to eq('new test')
        expect(connection).to have_received(:get_workflow_execution_history).twice
      end
    end

    context 'when workflow has completed' do
      let(:event_proto) do
        Temporalio::Api::History::V1::HistoryEvent.new(
          event_type: :EVENT_TYPE_WORKFLOW_EXECUTION_COMPLETED,
          workflow_execution_completed_event_attributes: {
            result: { payloads: [payload_proto] },
            new_execution_run_id: new_run_id,
          }
        )
      end

      it 'calls the RPC method' do
        subject.await_workflow_result(id, run_id, false, metadata, timeout)

        expect(connection).to have_received(:get_workflow_execution_history).once do |request, **rpc_params|
          expect(request)
            .to be_a(Temporalio::Api::WorkflowService::V1::GetWorkflowExecutionHistoryRequest)
          expect(request.namespace).to eq(namespace)
          expect(request.execution.workflow_id).to eq(id)
          expect(request.execution.run_id).to eq(run_id)
          expect(request.history_event_filter_type).to eq(:HISTORY_EVENT_FILTER_TYPE_CLOSE_EVENT)
          expect(request.wait_new_event).to eq(true)
          expect(request.skip_archival).to eq(true)
          expect(rpc_params[:metadata]).to eq(metadata)
          expect(rpc_params[:timeout]).to eq(timeout)
        end
      end

      it 'returns the result' do
        expect(subject.await_workflow_result(id, run_id, false, metadata, timeout)).to eq('test')
      end

      include_examples 'follow runs'
    end

    context 'when workflow has failed' do
      let(:event_proto) do
        Temporalio::Api::History::V1::HistoryEvent.new(
          event_type: :EVENT_TYPE_WORKFLOW_EXECUTION_FAILED,
          workflow_execution_failed_event_attributes: {
            failure: failure_proto,
            new_execution_run_id: new_run_id,
          },
        )
      end

      it 'raises an error' do
        expect do
          subject.await_workflow_result(id, run_id, false, metadata, timeout)
        end.to raise_error do |error|
          expect(error).to be_a(Temporalio::Error::WorkflowFailure)
          expect(error.cause).to be_a(Temporalio::Error::ApplicationError)
          expect(error.cause.message).to eq('Test error')
        end

        expect(connection).to have_received(:get_workflow_execution_history).once
      end

      include_examples 'follow runs'
    end

    context 'when workflow was cancelled' do
      let(:event_proto) do
        Temporalio::Api::History::V1::HistoryEvent.new(
          event_type: :EVENT_TYPE_WORKFLOW_EXECUTION_CANCELED,
          workflow_execution_canceled_event_attributes: {
            details: { payloads: [payload_proto] },
          },
        )
      end

      it 'raises an error' do
        expect do
          subject.await_workflow_result(id, run_id, false, metadata, timeout)
        end.to raise_error do |error|
          expect(error).to be_a(Temporalio::Error::WorkflowFailure)
          expect(error.cause).to be_a(Temporalio::Error::CancelledError)
          expect(error.cause.message).to eq('Workflow execution cancelled')
          expect(error.cause.details).to eq(['test'])
        end

        expect(connection).to have_received(:get_workflow_execution_history).once
      end
    end

    context 'when workflow was terminated' do
      let(:event_proto) do
        Temporalio::Api::History::V1::HistoryEvent.new(
          event_type: :EVENT_TYPE_WORKFLOW_EXECUTION_TERMINATED,
          workflow_execution_terminated_event_attributes: {
            reason: 'test reason',
            details: { payloads: [payload_proto] },
          },
        )
      end

      it 'raises an error' do
        expect do
          subject.await_workflow_result(id, run_id, false, metadata, timeout)
        end.to raise_error do |error|
          expect(error).to be_a(Temporalio::Error::WorkflowFailure)
          expect(error.cause).to be_a(Temporalio::Error::TerminatedError)
          expect(error.cause.message).to eq('test reason')
        end

        expect(connection).to have_received(:get_workflow_execution_history).once
      end
    end

    context 'when workflow has timed out' do
      let(:event_proto) do
        Temporalio::Api::History::V1::HistoryEvent.new(
          event_type: :EVENT_TYPE_WORKFLOW_EXECUTION_TIMED_OUT,
          workflow_execution_timed_out_event_attributes: {
            new_execution_run_id: new_run_id,
          },
        )
      end

      it 'raises an error' do
        expect do
          subject.await_workflow_result(id, run_id, false, metadata, timeout)
        end.to raise_error do |error|
          expect(error).to be_a(Temporalio::Error::WorkflowFailure)
          expect(error.cause).to be_a(Temporalio::Error::TimeoutError)
          expect(error.cause.message).to eq('Workflow execution timed out')
          expect(error.cause.type).to eq(Temporalio::TimeoutType::START_TO_CLOSE)
        end

        expect(connection).to have_received(:get_workflow_execution_history).once
      end

      include_examples 'follow runs'
    end

    context 'when workflow has timed out' do
      let(:event_proto) do
        Temporalio::Api::History::V1::HistoryEvent.new(
          event_type: :EVENT_TYPE_WORKFLOW_EXECUTION_CONTINUED_AS_NEW,
          workflow_execution_continued_as_new_event_attributes: {
            new_execution_run_id: new_run_id,
          },
        )
      end

      it 'raises an error' do
        expect do
          subject.await_workflow_result(id, run_id, false, metadata, timeout)
        end.to raise_error(Temporalio::Error, 'Workflow execution continued as new')
        expect(connection).to have_received(:get_workflow_execution_history).once
      end

      include_examples 'follow runs'
    end
  end
end
