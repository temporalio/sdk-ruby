require 'json'
require 'securerandom'
require 'socket'
require 'temporal/workflow/handle'
require 'temporal/workflow/execution_info'

module Temporal
  class Client
    attr_reader :namespace, :identity

    # TODO: More argument to follow for converters, encoders, etc
    def initialize(connection, namespace)
      @connection = connection
      @namespace = namespace
      @identity = "#{Process.pid}@#{Socket.gethostname}"
    end

    def workflow_handle(id, run_id = nil)
      Workflow::Handle.new(self, id, run_id)
    end

    def start_workflow(workflow, *args, **options)
      name = workflow
      id = options[:id]
      task_queue = options[:task_queue]

      request = Temporal::Api::WorkflowService::V1::StartWorkflowExecutionRequest.new(
        identity: identity,
        namespace: namespace,
        workflow_type: Temporal::Api::Common::V1::WorkflowType.new(name: name),
        workflow_id: id,
        task_queue: Temporal::Api::TaskQueue::V1::TaskQueue.new(name: task_queue),
        input: to_payloads(args),
        request_id: SecureRandom.uuid,
      )

      puts request.input

      response = connection.start_workflow_execution(request)

      workflow_handle(id, response.run_id)
    end

    def await_workflow_result(id, run_id, timeout: nil)
      deadline = timeout ? Time.now + timeout : nil
      request = Temporal::Api::WorkflowService::V1::GetWorkflowExecutionHistoryRequest.new(
        namespace: namespace,
        execution: Temporal::Api::Common::V1::WorkflowExecution.new(
          workflow_id: id,
          run_id: run_id,
        ),
        history_event_filter_type:
          Temporal::Api::Enums::V1::HistoryEventFilterType::HISTORY_EVENT_FILTER_TYPE_CLOSE_EVENT,
        wait_new_event: true,
        skip_archival: true,
      )

      response = connection.get_workflow_execution_history(request)
      event = response.history.events.first

      # TODO: handle exception cases
      from_payloads(event.workflow_execution_completed_event_attributes.result)&.first
    end

    def describe_workflow(id, run_id)
      request = Temporal::Api::WorkflowService::V1::DescribeWorkflowExecutionRequest.new(
        namespace: namespace,
        execution: Temporal::Api::Common::V1::WorkflowExecution.new(
          workflow_id: id,
          run_id: run_id,
        ),
      )

      response = connection.describe_workflow_execution(request)

      Workflow::ExecutionInfo.from_raw(response)
    end

    def query_workflow(id, run_id, query:, input: nil)
      request = Temporal::Api::WorkflowService::V1::QueryWorkflowRequest.new(
        namespace: namespace,
        execution: Temporal::Api::Common::V1::WorkflowExecution.new(
          workflow_id: id,
          run_id: run_id,
        ),
        query: Temporal::Api::Query::V1::WorkflowQuery.new(
          query_type: query,
          query_args: to_payloads(input),
        ),
      )

      response = connection.query_workflow(request)
    end

    def signal_workflow(id, run_id, signal:, input: nil)
      request = Temporal::Api::WorkflowService::V1::SignalWorkflowExecutionRequest.new(
        namespace: namespace,
        workflow_execution: Temporal::Api::Common::V1::WorkflowExecution.new(
          workflow_id: id,
          run_id: run_id
        ),
        signal_name: signal,
        input: to_payloads(input),
        identity: identity,
      )

      response = connection.signal_workflow_execution(request)
    end

    def cancel_workflow(id, run_id, reason: nil)
      request = Temporal::Api::WorkflowService::V1::RequestCancelWorkflowExecutionRequest.new(
        namespace: namespace,
        execution: Temporal::Api::Common::V1::WorkflowExecution.new(
          workflow_id: id,
          run_id: run_id,
        ),
        reason: reason,
      )

      connection.request_cancel_workflow_execution(request)
    end

    def terminate_workflow(id, run_id, reason: nil, details: nil)
      request = Temporal::Api::WorkflowService::V1::TerminateWorkflowExecutionRequest.new(
        identity: identity,
        namespace: namespace,
        workflow_execution: Temporal::Api::Common::V1::WorkflowExecution.new(
          workflow_id: id,
          run_id: run_id,
        ),
        reason: reason,
        details: to_payloads(details),
      )

      connection.terminate_workflow_execution(request)

      nil
    end

    private

    JSON_ENCODING = 'json/plain'.freeze

    attr_reader :connection

    # TODO: To be re-implemented with data converters and encoders
    def to_payloads(data)
      payloads = data.map do |data|
        Temporal::Api::Common::V1::Payload.new(
          metadata: { 'encoding' => JSON_ENCODING },
          data: JSON.generate(data).b,
        )
      end

      Temporal::Api::Common::V1::Payloads.new(payloads: payloads)
    end

    # TODO: To be re-implemented with data converters and encoders
    def from_payloads(payloads)
      payloads.payloads.map do |payload|
        JSON.parse(payload.data) if payload.metadata['encoding'] == JSON_ENCODING
      end
    end
  end
end
