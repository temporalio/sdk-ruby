require 'temporal/api/workflowservice/v1/request_response_pb'
require 'temporal/bridge'

module Temporal
  class Connection
    def initialize(host)
      @core_connection = Temporal::Bridge::Connection.connect(host)
    end

    def register_namespace(request)
      encoded = Temporal::Api::WorkflowService::V1::RegisterNamespaceRequest.encode(request)
      response = core_connection.call(:register_namespace, encoded)

      Temporal::Api::WorkflowService::V1::RegisterNamespaceResponse.decode(response)
    end

    def describe_namespace(request)
      encoded = Temporal::Api::WorkflowService::V1::DescribeNamespaceRequest.encode(request)
      response = core_connection.call(:describe_namespace, encoded)

      Temporal::Api::WorkflowService::V1::DescribeNamespaceResponse.decode(response)
    end

    def list_namespaces(request)
      encoded = Temporal::Api::WorkflowService::V1::ListNamespacesRequest.encode(request)
      response = core_connection.call(:list_namespaces, encoded)

      Temporal::Api::WorkflowService::V1::ListNamespacesResponse.decode(response)
    end

    def update_namespace(request)
      encoded = Temporal::Api::WorkflowService::V1::UpdateNamespaceRequest.encode(request)
      response = core_connection.call(:update_namespace, encoded)

      Temporal::Api::WorkflowService::V1::UpdateNamespaceResponse.decode(response)
    end

    def deprecate_namespace(request)
      encoded = Temporal::Api::WorkflowService::V1::DeprecateNamespaceRequest.encode(request)
      response = core_connection.call(:deprecate_namespace, encoded)

      Temporal::Api::WorkflowService::V1::DeprecateNamespaceResponse.decode(response)
    end

    def start_workflow_execution(request)
      encoded = Temporal::Api::WorkflowService::V1::StartWorkflowExecutionRequest.encode(request)
      response = core_connection.call(:start_workflow_execution, encoded)

      Temporal::Api::WorkflowService::V1::StartWorkflowExecutionResponse.decode(response)
    end

    def get_workflow_execution_history(request)
      encoded = Temporal::Api::WorkflowService::V1::GetWorkflowExecutionHistoryRequest.encode(request)
      response = core_connection.call(:get_workflow_execution_history, encoded)

      Temporal::Api::WorkflowService::V1::GetWorkflowExecutionHistoryResponse.decode(response)
    end

    def get_workflow_execution_history_reverse(request)
      encoded = Temporal::Api::WorkflowService::V1::GetWorkflowExecutionHistoryReverseRequest.encode(request)
      response = core_connection.call(:get_workflow_execution_history_reverse, encoded)

      Temporal::Api::WorkflowService::V1::GetWorkflowExecutionHistoryReverseResponse.decode(response)
    end

    def poll_workflow_task_queue(request)
      encoded = Temporal::Api::WorkflowService::V1::PollWorkflowTaskQueueRequest.encode(request)
      response = core_connection.call(:poll_workflow_task_queue, encoded)

      Temporal::Api::WorkflowService::V1::PollWorkflowTaskQueueResponse.decode(response)
    end

    def respond_workflow_task_completed(request)
      encoded = Temporal::Api::WorkflowService::V1::RespondWorkflowTaskCompletedRequest.encode(request)
      response = core_connection.call(:respond_workflow_task_completed, encoded)

      Temporal::Api::WorkflowService::V1::RespondWorkflowTaskCompletedResponse.decode(response)
    end

    def respond_workflow_task_failed(request)
      encoded = Temporal::Api::WorkflowService::V1::RespondWorkflowTaskFailedRequest.encode(request)
      response = core_connection.call(:respond_workflow_task_failed, encoded)

      Temporal::Api::WorkflowService::V1::RespondWorkflowTaskFailedResponse.decode(response)
    end

    def poll_activity_task_queue(request)
      encoded = Temporal::Api::WorkflowService::V1::PollActivityTaskQueueRequest.encode(request)
      response = core_connection.call(:poll_activity_task_queue, encoded)

      Temporal::Api::WorkflowService::V1::PollActivityTaskQueueResponse.decode(response)
    end

    def record_activity_task_heartbeat(request)
      encoded = Temporal::Api::WorkflowService::V1::RecordActivityTaskHeartbeatRequest.encode(request)
      response = core_connection.call(:record_activity_task_heartbeat, encoded)

      Temporal::Api::WorkflowService::V1::RecordActivityTaskHeartbeatResponse.decode(response)
    end

    def record_activity_task_heartbeat_by_id(request)
      encoded = Temporal::Api::WorkflowService::V1::RecordActivityTaskHeartbeatByIdRequest.encode(request)
      response = core_connection.call(:record_activity_task_heartbeat_by_id, encoded)

      Temporal::Api::WorkflowService::V1::RecordActivityTaskHeartbeatByIdResponse.decode(response)
    end

    def respond_activity_task_completed(request)
      encoded = Temporal::Api::WorkflowService::V1::RespondActivityTaskCompletedRequest.encode(request)
      response = core_connection.call(:respond_activity_task_completed, encoded)

      Temporal::Api::WorkflowService::V1::RespondActivityTaskCompletedResponse.decode(response)
    end

    def respond_activity_task_completed_by_id(request)
      encoded = Temporal::Api::WorkflowService::V1::RespondActivityTaskCompletedByIdRequest.encode(request)
      response = core_connection.call(:respond_activity_task_completed_by_id, encoded)

      Temporal::Api::WorkflowService::V1::RespondActivityTaskCompletedByIdResponse.decode(response)
    end

    def respond_activity_task_failed(request)
      encoded = Temporal::Api::WorkflowService::V1::RespondActivityTaskFailedRequest.encode(request)
      response = core_connection.call(:respond_activity_task_failed, encoded)

      Temporal::Api::WorkflowService::V1::RespondActivityTaskFailedResponse.decode(response)
    end

    def respond_activity_task_failed_by_id(request)
      encoded = Temporal::Api::WorkflowService::V1::RespondActivityTaskFailedByIdRequest.encode(request)
      response = core_connection.call(:respond_activity_task_failed_by_id, encoded)

      Temporal::Api::WorkflowService::V1::RespondActivityTaskFailedByIdResponse.decode(response)
    end

    def respond_activity_task_canceled(request)
      encoded = Temporal::Api::WorkflowService::V1::RespondActivityTaskCanceledRequest.encode(request)
      response = core_connection.call(:respond_activity_task_canceled, encoded)

      Temporal::Api::WorkflowService::V1::RespondActivityTaskCanceledResponse.decode(response)
    end

    def respond_activity_task_canceled_by_id(request)
      encoded = Temporal::Api::WorkflowService::V1::RespondActivityTaskCanceledByIdRequest.encode(request)
      response = core_connection.call(:respond_activity_task_canceled_by_id, encoded)

      Temporal::Api::WorkflowService::V1::RespondActivityTaskCanceledByIdResponse.decode(response)
    end

    def request_cancel_workflow_execution(request)
      encoded = Temporal::Api::WorkflowService::V1::RequestCancelWorkflowExecutionRequest.encode(request)
      response = core_connection.call(:request_cancel_workflow_execution, encoded)

      Temporal::Api::WorkflowService::V1::RequestCancelWorkflowExecutionResponse.decode(response)
    end

    def signal_workflow_execution(request)
      encoded = Temporal::Api::WorkflowService::V1::SignalWorkflowExecutionRequest.encode(request)
      response = core_connection.call(:signal_workflow_execution, encoded)

      Temporal::Api::WorkflowService::V1::SignalWorkflowExecutionResponse.decode(response)
    end

    def signal_with_start_workflow_execution(request)
      encoded = Temporal::Api::WorkflowService::V1::SignalWithStartWorkflowExecutionRequest.encode(request)
      response = core_connection.call(:signal_with_start_workflow_execution, encoded)

      Temporal::Api::WorkflowService::V1::SignalWithStartWorkflowExecutionResponse.decode(response)
    end

    def reset_workflow_execution(request)
      encoded = Temporal::Api::WorkflowService::V1::ResetWorkflowExecutionRequest.encode(request)
      response = core_connection.call(:reset_workflow_execution, encoded)

      Temporal::Api::WorkflowService::V1::ResetWorkflowExecutionResponse.decode(response)
    end

    def terminate_workflow_execution(request)
      encoded = Temporal::Api::WorkflowService::V1::TerminateWorkflowExecutionRequest.encode(request)
      response = core_connection.call(:terminate_workflow_execution, encoded)

      Temporal::Api::WorkflowService::V1::TerminateWorkflowExecutionResponse.decode(response)
    end

    def list_open_workflow_executions(request)
      encoded = Temporal::Api::WorkflowService::V1::ListOpenWorkflowExecutionsRequest.encode(request)
      response = core_connection.call(:list_open_workflow_executions, encoded)

      Temporal::Api::WorkflowService::V1::ListOpenWorkflowExecutionsResponse.decode(response)
    end

    def list_closed_workflow_executions(request)
      encoded = Temporal::Api::WorkflowService::V1::ListClosedWorkflowExecutionsRequest.encode(request)
      response = core_connection.call(:list_closed_workflow_executions, encoded)

      Temporal::Api::WorkflowService::V1::ListClosedWorkflowExecutionsResponse.decode(response)
    end

    def list_workflow_executions(request)
      encoded = Temporal::Api::WorkflowService::V1::ListWorkflowExecutionsRequest.encode(request)
      response = core_connection.call(:list_workflow_executions, encoded)

      Temporal::Api::WorkflowService::V1::ListWorkflowExecutionsResponse.decode(response)
    end

    def list_archived_workflow_executions(request)
      encoded = Temporal::Api::WorkflowService::V1::ListArchivedWorkflowExecutionsRequest.encode(request)
      response = core_connection.call(:list_archived_workflow_executions, encoded)

      Temporal::Api::WorkflowService::V1::ListArchivedWorkflowExecutionsResponse.decode(response)
    end

    def scan_workflow_executions(request)
      encoded = Temporal::Api::WorkflowService::V1::ScanWorkflowExecutionsRequest.encode(request)
      response = core_connection.call(:scan_workflow_executions, encoded)

      Temporal::Api::WorkflowService::V1::ScanWorkflowExecutionsResponse.decode(response)
    end

    def count_workflow_executions(request)
      encoded = Temporal::Api::WorkflowService::V1::CountWorkflowExecutionsRequest.encode(request)
      response = core_connection.call(:count_workflow_executions, encoded)

      Temporal::Api::WorkflowService::V1::CountWorkflowExecutionsResponse.decode(response)
    end

    def get_search_attributes(request)
      encoded = Temporal::Api::WorkflowService::V1::GetSearchAttributesRequest.encode(request)
      response = core_connection.call(:get_search_attributes, encoded)

      Temporal::Api::WorkflowService::V1::GetSearchAttributesResponse.decode(response)
    end

    def respond_query_task_completed(request)
      encoded = Temporal::Api::WorkflowService::V1::RespondQueryTaskCompletedRequest.encode(request)
      response = core_connection.call(:respond_query_task_completed, encoded)

      Temporal::Api::WorkflowService::V1::RespondQueryTaskCompletedResponse.decode(response)
    end

    def reset_sticky_task_queue(request)
      encoded = Temporal::Api::WorkflowService::V1::ResetStickyTaskQueueRequest.encode(request)
      response = core_connection.call(:reset_sticky_task_queue, encoded)

      Temporal::Api::WorkflowService::V1::ResetStickyTaskQueueResponse.decode(response)
    end

    def query_workflow(request)
      encoded = Temporal::Api::WorkflowService::V1::QueryWorkflowRequest.encode(request)
      response = core_connection.call(:query_workflow, encoded)

      Temporal::Api::WorkflowService::V1::QueryWorkflowResponse.decode(response)
    end

    def describe_workflow_execution(request)
      encoded = Temporal::Api::WorkflowService::V1::DescribeWorkflowExecutionRequest.encode(request)
      response = core_connection.call(:describe_workflow_execution, encoded)

      Temporal::Api::WorkflowService::V1::DescribeWorkflowExecutionResponse.decode(response)
    end

    def describe_task_queue(request)
      encoded = Temporal::Api::WorkflowService::V1::DescribeTaskQueueRequest.encode(request)
      response = core_connection.call(:describe_task_queue, encoded)

      Temporal::Api::WorkflowService::V1::DescribeTaskQueueResponse.decode(response)
    end

    def get_cluster_info(request)
      encoded = Temporal::Api::WorkflowService::V1::GetClusterInfoRequest.encode(request)
      response = core_connection.call(:get_cluster_info, encoded)

      Temporal::Api::WorkflowService::V1::GetClusterInfoResponse.decode(response)
    end

    def get_system_info(request)
      encoded = Temporal::Api::WorkflowService::V1::GetSystemInfoRequest.encode(request)
      response = core_connection.call(:get_system_info, encoded)

      Temporal::Api::WorkflowService::V1::GetSystemInfoResponse.decode(response)
    end

    def list_task_queue_partitions(request)
      encoded = Temporal::Api::WorkflowService::V1::ListTaskQueuePartitionsRequest.encode(request)
      response = core_connection.call(:list_task_queue_partitions, encoded)

      Temporal::Api::WorkflowService::V1::ListTaskQueuePartitionsResponse.decode(response)
    end

    private

    attr_reader :core_connection
  end
end
