# frozen_string_literal: true

# Generated code.  DO NOT EDIT!

require 'temporalio/api'
require 'temporalio/client/connection/service'
require 'temporalio/internal/bridge/client'

module Temporalio
  class Client
    class Connection
      # WorkflowService API.
      class WorkflowService < Service
        # @!visibility private
        def initialize(connection)
          super(connection, Internal::Bridge::Client::SERVICE_WORKFLOW)
        end

        # Calls WorkflowService.RegisterNamespace API call.
        #
        # @param request [Temporalio::Api::WorkflowService::V1::RegisterNamespaceRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::WorkflowService::V1::RegisterNamespaceResponse] API response.
        def register_namespace(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'register_namespace',
            request_class: Temporalio::Api::WorkflowService::V1::RegisterNamespaceRequest,
            response_class: Temporalio::Api::WorkflowService::V1::RegisterNamespaceResponse,
            request:,
            rpc_options:
          )
        end

        # Calls WorkflowService.DescribeNamespace API call.
        #
        # @param request [Temporalio::Api::WorkflowService::V1::DescribeNamespaceRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::WorkflowService::V1::DescribeNamespaceResponse] API response.
        def describe_namespace(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'describe_namespace',
            request_class: Temporalio::Api::WorkflowService::V1::DescribeNamespaceRequest,
            response_class: Temporalio::Api::WorkflowService::V1::DescribeNamespaceResponse,
            request:,
            rpc_options:
          )
        end

        # Calls WorkflowService.ListNamespaces API call.
        #
        # @param request [Temporalio::Api::WorkflowService::V1::ListNamespacesRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::WorkflowService::V1::ListNamespacesResponse] API response.
        def list_namespaces(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'list_namespaces',
            request_class: Temporalio::Api::WorkflowService::V1::ListNamespacesRequest,
            response_class: Temporalio::Api::WorkflowService::V1::ListNamespacesResponse,
            request:,
            rpc_options:
          )
        end

        # Calls WorkflowService.UpdateNamespace API call.
        #
        # @param request [Temporalio::Api::WorkflowService::V1::UpdateNamespaceRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::WorkflowService::V1::UpdateNamespaceResponse] API response.
        def update_namespace(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'update_namespace',
            request_class: Temporalio::Api::WorkflowService::V1::UpdateNamespaceRequest,
            response_class: Temporalio::Api::WorkflowService::V1::UpdateNamespaceResponse,
            request:,
            rpc_options:
          )
        end

        # Calls WorkflowService.DeprecateNamespace API call.
        #
        # @param request [Temporalio::Api::WorkflowService::V1::DeprecateNamespaceRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::WorkflowService::V1::DeprecateNamespaceResponse] API response.
        def deprecate_namespace(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'deprecate_namespace',
            request_class: Temporalio::Api::WorkflowService::V1::DeprecateNamespaceRequest,
            response_class: Temporalio::Api::WorkflowService::V1::DeprecateNamespaceResponse,
            request:,
            rpc_options:
          )
        end

        # Calls WorkflowService.StartWorkflowExecution API call.
        #
        # @param request [Temporalio::Api::WorkflowService::V1::StartWorkflowExecutionRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::WorkflowService::V1::StartWorkflowExecutionResponse] API response.
        def start_workflow_execution(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'start_workflow_execution',
            request_class: Temporalio::Api::WorkflowService::V1::StartWorkflowExecutionRequest,
            response_class: Temporalio::Api::WorkflowService::V1::StartWorkflowExecutionResponse,
            request:,
            rpc_options:
          )
        end

        # Calls WorkflowService.ExecuteMultiOperation API call.
        #
        # @param request [Temporalio::Api::WorkflowService::V1::ExecuteMultiOperationRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::WorkflowService::V1::ExecuteMultiOperationResponse] API response.
        def execute_multi_operation(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'execute_multi_operation',
            request_class: Temporalio::Api::WorkflowService::V1::ExecuteMultiOperationRequest,
            response_class: Temporalio::Api::WorkflowService::V1::ExecuteMultiOperationResponse,
            request:,
            rpc_options:
          )
        end

        # Calls WorkflowService.GetWorkflowExecutionHistory API call.
        #
        # @param request [Temporalio::Api::WorkflowService::V1::GetWorkflowExecutionHistoryRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::WorkflowService::V1::GetWorkflowExecutionHistoryResponse] API response.
        def get_workflow_execution_history(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'get_workflow_execution_history',
            request_class: Temporalio::Api::WorkflowService::V1::GetWorkflowExecutionHistoryRequest,
            response_class: Temporalio::Api::WorkflowService::V1::GetWorkflowExecutionHistoryResponse,
            request:,
            rpc_options:
          )
        end

        # Calls WorkflowService.GetWorkflowExecutionHistoryReverse API call.
        #
        # @param request [Temporalio::Api::WorkflowService::V1::GetWorkflowExecutionHistoryReverseRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::WorkflowService::V1::GetWorkflowExecutionHistoryReverseResponse] API response.
        def get_workflow_execution_history_reverse(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'get_workflow_execution_history_reverse',
            request_class: Temporalio::Api::WorkflowService::V1::GetWorkflowExecutionHistoryReverseRequest,
            response_class: Temporalio::Api::WorkflowService::V1::GetWorkflowExecutionHistoryReverseResponse,
            request:,
            rpc_options:
          )
        end

        # Calls WorkflowService.PollWorkflowTaskQueue API call.
        #
        # @param request [Temporalio::Api::WorkflowService::V1::PollWorkflowTaskQueueRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::WorkflowService::V1::PollWorkflowTaskQueueResponse] API response.
        def poll_workflow_task_queue(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'poll_workflow_task_queue',
            request_class: Temporalio::Api::WorkflowService::V1::PollWorkflowTaskQueueRequest,
            response_class: Temporalio::Api::WorkflowService::V1::PollWorkflowTaskQueueResponse,
            request:,
            rpc_options:
          )
        end

        # Calls WorkflowService.RespondWorkflowTaskCompleted API call.
        #
        # @param request [Temporalio::Api::WorkflowService::V1::RespondWorkflowTaskCompletedRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::WorkflowService::V1::RespondWorkflowTaskCompletedResponse] API response.
        def respond_workflow_task_completed(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'respond_workflow_task_completed',
            request_class: Temporalio::Api::WorkflowService::V1::RespondWorkflowTaskCompletedRequest,
            response_class: Temporalio::Api::WorkflowService::V1::RespondWorkflowTaskCompletedResponse,
            request:,
            rpc_options:
          )
        end

        # Calls WorkflowService.RespondWorkflowTaskFailed API call.
        #
        # @param request [Temporalio::Api::WorkflowService::V1::RespondWorkflowTaskFailedRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::WorkflowService::V1::RespondWorkflowTaskFailedResponse] API response.
        def respond_workflow_task_failed(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'respond_workflow_task_failed',
            request_class: Temporalio::Api::WorkflowService::V1::RespondWorkflowTaskFailedRequest,
            response_class: Temporalio::Api::WorkflowService::V1::RespondWorkflowTaskFailedResponse,
            request:,
            rpc_options:
          )
        end

        # Calls WorkflowService.PollActivityTaskQueue API call.
        #
        # @param request [Temporalio::Api::WorkflowService::V1::PollActivityTaskQueueRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::WorkflowService::V1::PollActivityTaskQueueResponse] API response.
        def poll_activity_task_queue(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'poll_activity_task_queue',
            request_class: Temporalio::Api::WorkflowService::V1::PollActivityTaskQueueRequest,
            response_class: Temporalio::Api::WorkflowService::V1::PollActivityTaskQueueResponse,
            request:,
            rpc_options:
          )
        end

        # Calls WorkflowService.RecordActivityTaskHeartbeat API call.
        #
        # @param request [Temporalio::Api::WorkflowService::V1::RecordActivityTaskHeartbeatRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::WorkflowService::V1::RecordActivityTaskHeartbeatResponse] API response.
        def record_activity_task_heartbeat(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'record_activity_task_heartbeat',
            request_class: Temporalio::Api::WorkflowService::V1::RecordActivityTaskHeartbeatRequest,
            response_class: Temporalio::Api::WorkflowService::V1::RecordActivityTaskHeartbeatResponse,
            request:,
            rpc_options:
          )
        end

        # Calls WorkflowService.RecordActivityTaskHeartbeatById API call.
        #
        # @param request [Temporalio::Api::WorkflowService::V1::RecordActivityTaskHeartbeatByIdRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::WorkflowService::V1::RecordActivityTaskHeartbeatByIdResponse] API response.
        def record_activity_task_heartbeat_by_id(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'record_activity_task_heartbeat_by_id',
            request_class: Temporalio::Api::WorkflowService::V1::RecordActivityTaskHeartbeatByIdRequest,
            response_class: Temporalio::Api::WorkflowService::V1::RecordActivityTaskHeartbeatByIdResponse,
            request:,
            rpc_options:
          )
        end

        # Calls WorkflowService.RespondActivityTaskCompleted API call.
        #
        # @param request [Temporalio::Api::WorkflowService::V1::RespondActivityTaskCompletedRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::WorkflowService::V1::RespondActivityTaskCompletedResponse] API response.
        def respond_activity_task_completed(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'respond_activity_task_completed',
            request_class: Temporalio::Api::WorkflowService::V1::RespondActivityTaskCompletedRequest,
            response_class: Temporalio::Api::WorkflowService::V1::RespondActivityTaskCompletedResponse,
            request:,
            rpc_options:
          )
        end

        # Calls WorkflowService.RespondActivityTaskCompletedById API call.
        #
        # @param request [Temporalio::Api::WorkflowService::V1::RespondActivityTaskCompletedByIdRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::WorkflowService::V1::RespondActivityTaskCompletedByIdResponse] API response.
        def respond_activity_task_completed_by_id(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'respond_activity_task_completed_by_id',
            request_class: Temporalio::Api::WorkflowService::V1::RespondActivityTaskCompletedByIdRequest,
            response_class: Temporalio::Api::WorkflowService::V1::RespondActivityTaskCompletedByIdResponse,
            request:,
            rpc_options:
          )
        end

        # Calls WorkflowService.RespondActivityTaskFailed API call.
        #
        # @param request [Temporalio::Api::WorkflowService::V1::RespondActivityTaskFailedRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::WorkflowService::V1::RespondActivityTaskFailedResponse] API response.
        def respond_activity_task_failed(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'respond_activity_task_failed',
            request_class: Temporalio::Api::WorkflowService::V1::RespondActivityTaskFailedRequest,
            response_class: Temporalio::Api::WorkflowService::V1::RespondActivityTaskFailedResponse,
            request:,
            rpc_options:
          )
        end

        # Calls WorkflowService.RespondActivityTaskFailedById API call.
        #
        # @param request [Temporalio::Api::WorkflowService::V1::RespondActivityTaskFailedByIdRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::WorkflowService::V1::RespondActivityTaskFailedByIdResponse] API response.
        def respond_activity_task_failed_by_id(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'respond_activity_task_failed_by_id',
            request_class: Temporalio::Api::WorkflowService::V1::RespondActivityTaskFailedByIdRequest,
            response_class: Temporalio::Api::WorkflowService::V1::RespondActivityTaskFailedByIdResponse,
            request:,
            rpc_options:
          )
        end

        # Calls WorkflowService.RespondActivityTaskCanceled API call.
        #
        # @param request [Temporalio::Api::WorkflowService::V1::RespondActivityTaskCanceledRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::WorkflowService::V1::RespondActivityTaskCanceledResponse] API response.
        def respond_activity_task_canceled(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'respond_activity_task_canceled',
            request_class: Temporalio::Api::WorkflowService::V1::RespondActivityTaskCanceledRequest,
            response_class: Temporalio::Api::WorkflowService::V1::RespondActivityTaskCanceledResponse,
            request:,
            rpc_options:
          )
        end

        # Calls WorkflowService.RespondActivityTaskCanceledById API call.
        #
        # @param request [Temporalio::Api::WorkflowService::V1::RespondActivityTaskCanceledByIdRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::WorkflowService::V1::RespondActivityTaskCanceledByIdResponse] API response.
        def respond_activity_task_canceled_by_id(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'respond_activity_task_canceled_by_id',
            request_class: Temporalio::Api::WorkflowService::V1::RespondActivityTaskCanceledByIdRequest,
            response_class: Temporalio::Api::WorkflowService::V1::RespondActivityTaskCanceledByIdResponse,
            request:,
            rpc_options:
          )
        end

        # Calls WorkflowService.RequestCancelWorkflowExecution API call.
        #
        # @param request [Temporalio::Api::WorkflowService::V1::RequestCancelWorkflowExecutionRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::WorkflowService::V1::RequestCancelWorkflowExecutionResponse] API response.
        def request_cancel_workflow_execution(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'request_cancel_workflow_execution',
            request_class: Temporalio::Api::WorkflowService::V1::RequestCancelWorkflowExecutionRequest,
            response_class: Temporalio::Api::WorkflowService::V1::RequestCancelWorkflowExecutionResponse,
            request:,
            rpc_options:
          )
        end

        # Calls WorkflowService.SignalWorkflowExecution API call.
        #
        # @param request [Temporalio::Api::WorkflowService::V1::SignalWorkflowExecutionRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::WorkflowService::V1::SignalWorkflowExecutionResponse] API response.
        def signal_workflow_execution(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'signal_workflow_execution',
            request_class: Temporalio::Api::WorkflowService::V1::SignalWorkflowExecutionRequest,
            response_class: Temporalio::Api::WorkflowService::V1::SignalWorkflowExecutionResponse,
            request:,
            rpc_options:
          )
        end

        # Calls WorkflowService.SignalWithStartWorkflowExecution API call.
        #
        # @param request [Temporalio::Api::WorkflowService::V1::SignalWithStartWorkflowExecutionRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::WorkflowService::V1::SignalWithStartWorkflowExecutionResponse] API response.
        def signal_with_start_workflow_execution(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'signal_with_start_workflow_execution',
            request_class: Temporalio::Api::WorkflowService::V1::SignalWithStartWorkflowExecutionRequest,
            response_class: Temporalio::Api::WorkflowService::V1::SignalWithStartWorkflowExecutionResponse,
            request:,
            rpc_options:
          )
        end

        # Calls WorkflowService.ResetWorkflowExecution API call.
        #
        # @param request [Temporalio::Api::WorkflowService::V1::ResetWorkflowExecutionRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::WorkflowService::V1::ResetWorkflowExecutionResponse] API response.
        def reset_workflow_execution(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'reset_workflow_execution',
            request_class: Temporalio::Api::WorkflowService::V1::ResetWorkflowExecutionRequest,
            response_class: Temporalio::Api::WorkflowService::V1::ResetWorkflowExecutionResponse,
            request:,
            rpc_options:
          )
        end

        # Calls WorkflowService.TerminateWorkflowExecution API call.
        #
        # @param request [Temporalio::Api::WorkflowService::V1::TerminateWorkflowExecutionRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::WorkflowService::V1::TerminateWorkflowExecutionResponse] API response.
        def terminate_workflow_execution(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'terminate_workflow_execution',
            request_class: Temporalio::Api::WorkflowService::V1::TerminateWorkflowExecutionRequest,
            response_class: Temporalio::Api::WorkflowService::V1::TerminateWorkflowExecutionResponse,
            request:,
            rpc_options:
          )
        end

        # Calls WorkflowService.DeleteWorkflowExecution API call.
        #
        # @param request [Temporalio::Api::WorkflowService::V1::DeleteWorkflowExecutionRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::WorkflowService::V1::DeleteWorkflowExecutionResponse] API response.
        def delete_workflow_execution(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'delete_workflow_execution',
            request_class: Temporalio::Api::WorkflowService::V1::DeleteWorkflowExecutionRequest,
            response_class: Temporalio::Api::WorkflowService::V1::DeleteWorkflowExecutionResponse,
            request:,
            rpc_options:
          )
        end

        # Calls WorkflowService.ListOpenWorkflowExecutions API call.
        #
        # @param request [Temporalio::Api::WorkflowService::V1::ListOpenWorkflowExecutionsRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::WorkflowService::V1::ListOpenWorkflowExecutionsResponse] API response.
        def list_open_workflow_executions(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'list_open_workflow_executions',
            request_class: Temporalio::Api::WorkflowService::V1::ListOpenWorkflowExecutionsRequest,
            response_class: Temporalio::Api::WorkflowService::V1::ListOpenWorkflowExecutionsResponse,
            request:,
            rpc_options:
          )
        end

        # Calls WorkflowService.ListClosedWorkflowExecutions API call.
        #
        # @param request [Temporalio::Api::WorkflowService::V1::ListClosedWorkflowExecutionsRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::WorkflowService::V1::ListClosedWorkflowExecutionsResponse] API response.
        def list_closed_workflow_executions(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'list_closed_workflow_executions',
            request_class: Temporalio::Api::WorkflowService::V1::ListClosedWorkflowExecutionsRequest,
            response_class: Temporalio::Api::WorkflowService::V1::ListClosedWorkflowExecutionsResponse,
            request:,
            rpc_options:
          )
        end

        # Calls WorkflowService.ListWorkflowExecutions API call.
        #
        # @param request [Temporalio::Api::WorkflowService::V1::ListWorkflowExecutionsRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::WorkflowService::V1::ListWorkflowExecutionsResponse] API response.
        def list_workflow_executions(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'list_workflow_executions',
            request_class: Temporalio::Api::WorkflowService::V1::ListWorkflowExecutionsRequest,
            response_class: Temporalio::Api::WorkflowService::V1::ListWorkflowExecutionsResponse,
            request:,
            rpc_options:
          )
        end

        # Calls WorkflowService.ListArchivedWorkflowExecutions API call.
        #
        # @param request [Temporalio::Api::WorkflowService::V1::ListArchivedWorkflowExecutionsRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::WorkflowService::V1::ListArchivedWorkflowExecutionsResponse] API response.
        def list_archived_workflow_executions(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'list_archived_workflow_executions',
            request_class: Temporalio::Api::WorkflowService::V1::ListArchivedWorkflowExecutionsRequest,
            response_class: Temporalio::Api::WorkflowService::V1::ListArchivedWorkflowExecutionsResponse,
            request:,
            rpc_options:
          )
        end

        # Calls WorkflowService.ScanWorkflowExecutions API call.
        #
        # @param request [Temporalio::Api::WorkflowService::V1::ScanWorkflowExecutionsRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::WorkflowService::V1::ScanWorkflowExecutionsResponse] API response.
        def scan_workflow_executions(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'scan_workflow_executions',
            request_class: Temporalio::Api::WorkflowService::V1::ScanWorkflowExecutionsRequest,
            response_class: Temporalio::Api::WorkflowService::V1::ScanWorkflowExecutionsResponse,
            request:,
            rpc_options:
          )
        end

        # Calls WorkflowService.CountWorkflowExecutions API call.
        #
        # @param request [Temporalio::Api::WorkflowService::V1::CountWorkflowExecutionsRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::WorkflowService::V1::CountWorkflowExecutionsResponse] API response.
        def count_workflow_executions(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'count_workflow_executions',
            request_class: Temporalio::Api::WorkflowService::V1::CountWorkflowExecutionsRequest,
            response_class: Temporalio::Api::WorkflowService::V1::CountWorkflowExecutionsResponse,
            request:,
            rpc_options:
          )
        end

        # Calls WorkflowService.GetSearchAttributes API call.
        #
        # @param request [Temporalio::Api::WorkflowService::V1::GetSearchAttributesRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::WorkflowService::V1::GetSearchAttributesResponse] API response.
        def get_search_attributes(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'get_search_attributes',
            request_class: Temporalio::Api::WorkflowService::V1::GetSearchAttributesRequest,
            response_class: Temporalio::Api::WorkflowService::V1::GetSearchAttributesResponse,
            request:,
            rpc_options:
          )
        end

        # Calls WorkflowService.RespondQueryTaskCompleted API call.
        #
        # @param request [Temporalio::Api::WorkflowService::V1::RespondQueryTaskCompletedRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::WorkflowService::V1::RespondQueryTaskCompletedResponse] API response.
        def respond_query_task_completed(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'respond_query_task_completed',
            request_class: Temporalio::Api::WorkflowService::V1::RespondQueryTaskCompletedRequest,
            response_class: Temporalio::Api::WorkflowService::V1::RespondQueryTaskCompletedResponse,
            request:,
            rpc_options:
          )
        end

        # Calls WorkflowService.ResetStickyTaskQueue API call.
        #
        # @param request [Temporalio::Api::WorkflowService::V1::ResetStickyTaskQueueRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::WorkflowService::V1::ResetStickyTaskQueueResponse] API response.
        def reset_sticky_task_queue(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'reset_sticky_task_queue',
            request_class: Temporalio::Api::WorkflowService::V1::ResetStickyTaskQueueRequest,
            response_class: Temporalio::Api::WorkflowService::V1::ResetStickyTaskQueueResponse,
            request:,
            rpc_options:
          )
        end

        # Calls WorkflowService.ShutdownWorker API call.
        #
        # @param request [Temporalio::Api::WorkflowService::V1::ShutdownWorkerRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::WorkflowService::V1::ShutdownWorkerResponse] API response.
        def shutdown_worker(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'shutdown_worker',
            request_class: Temporalio::Api::WorkflowService::V1::ShutdownWorkerRequest,
            response_class: Temporalio::Api::WorkflowService::V1::ShutdownWorkerResponse,
            request:,
            rpc_options:
          )
        end

        # Calls WorkflowService.QueryWorkflow API call.
        #
        # @param request [Temporalio::Api::WorkflowService::V1::QueryWorkflowRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::WorkflowService::V1::QueryWorkflowResponse] API response.
        def query_workflow(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'query_workflow',
            request_class: Temporalio::Api::WorkflowService::V1::QueryWorkflowRequest,
            response_class: Temporalio::Api::WorkflowService::V1::QueryWorkflowResponse,
            request:,
            rpc_options:
          )
        end

        # Calls WorkflowService.DescribeWorkflowExecution API call.
        #
        # @param request [Temporalio::Api::WorkflowService::V1::DescribeWorkflowExecutionRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::WorkflowService::V1::DescribeWorkflowExecutionResponse] API response.
        def describe_workflow_execution(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'describe_workflow_execution',
            request_class: Temporalio::Api::WorkflowService::V1::DescribeWorkflowExecutionRequest,
            response_class: Temporalio::Api::WorkflowService::V1::DescribeWorkflowExecutionResponse,
            request:,
            rpc_options:
          )
        end

        # Calls WorkflowService.DescribeTaskQueue API call.
        #
        # @param request [Temporalio::Api::WorkflowService::V1::DescribeTaskQueueRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::WorkflowService::V1::DescribeTaskQueueResponse] API response.
        def describe_task_queue(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'describe_task_queue',
            request_class: Temporalio::Api::WorkflowService::V1::DescribeTaskQueueRequest,
            response_class: Temporalio::Api::WorkflowService::V1::DescribeTaskQueueResponse,
            request:,
            rpc_options:
          )
        end

        # Calls WorkflowService.GetClusterInfo API call.
        #
        # @param request [Temporalio::Api::WorkflowService::V1::GetClusterInfoRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::WorkflowService::V1::GetClusterInfoResponse] API response.
        def get_cluster_info(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'get_cluster_info',
            request_class: Temporalio::Api::WorkflowService::V1::GetClusterInfoRequest,
            response_class: Temporalio::Api::WorkflowService::V1::GetClusterInfoResponse,
            request:,
            rpc_options:
          )
        end

        # Calls WorkflowService.GetSystemInfo API call.
        #
        # @param request [Temporalio::Api::WorkflowService::V1::GetSystemInfoRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::WorkflowService::V1::GetSystemInfoResponse] API response.
        def get_system_info(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'get_system_info',
            request_class: Temporalio::Api::WorkflowService::V1::GetSystemInfoRequest,
            response_class: Temporalio::Api::WorkflowService::V1::GetSystemInfoResponse,
            request:,
            rpc_options:
          )
        end

        # Calls WorkflowService.ListTaskQueuePartitions API call.
        #
        # @param request [Temporalio::Api::WorkflowService::V1::ListTaskQueuePartitionsRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::WorkflowService::V1::ListTaskQueuePartitionsResponse] API response.
        def list_task_queue_partitions(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'list_task_queue_partitions',
            request_class: Temporalio::Api::WorkflowService::V1::ListTaskQueuePartitionsRequest,
            response_class: Temporalio::Api::WorkflowService::V1::ListTaskQueuePartitionsResponse,
            request:,
            rpc_options:
          )
        end

        # Calls WorkflowService.CreateSchedule API call.
        #
        # @param request [Temporalio::Api::WorkflowService::V1::CreateScheduleRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::WorkflowService::V1::CreateScheduleResponse] API response.
        def create_schedule(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'create_schedule',
            request_class: Temporalio::Api::WorkflowService::V1::CreateScheduleRequest,
            response_class: Temporalio::Api::WorkflowService::V1::CreateScheduleResponse,
            request:,
            rpc_options:
          )
        end

        # Calls WorkflowService.DescribeSchedule API call.
        #
        # @param request [Temporalio::Api::WorkflowService::V1::DescribeScheduleRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::WorkflowService::V1::DescribeScheduleResponse] API response.
        def describe_schedule(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'describe_schedule',
            request_class: Temporalio::Api::WorkflowService::V1::DescribeScheduleRequest,
            response_class: Temporalio::Api::WorkflowService::V1::DescribeScheduleResponse,
            request:,
            rpc_options:
          )
        end

        # Calls WorkflowService.UpdateSchedule API call.
        #
        # @param request [Temporalio::Api::WorkflowService::V1::UpdateScheduleRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::WorkflowService::V1::UpdateScheduleResponse] API response.
        def update_schedule(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'update_schedule',
            request_class: Temporalio::Api::WorkflowService::V1::UpdateScheduleRequest,
            response_class: Temporalio::Api::WorkflowService::V1::UpdateScheduleResponse,
            request:,
            rpc_options:
          )
        end

        # Calls WorkflowService.PatchSchedule API call.
        #
        # @param request [Temporalio::Api::WorkflowService::V1::PatchScheduleRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::WorkflowService::V1::PatchScheduleResponse] API response.
        def patch_schedule(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'patch_schedule',
            request_class: Temporalio::Api::WorkflowService::V1::PatchScheduleRequest,
            response_class: Temporalio::Api::WorkflowService::V1::PatchScheduleResponse,
            request:,
            rpc_options:
          )
        end

        # Calls WorkflowService.ListScheduleMatchingTimes API call.
        #
        # @param request [Temporalio::Api::WorkflowService::V1::ListScheduleMatchingTimesRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::WorkflowService::V1::ListScheduleMatchingTimesResponse] API response.
        def list_schedule_matching_times(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'list_schedule_matching_times',
            request_class: Temporalio::Api::WorkflowService::V1::ListScheduleMatchingTimesRequest,
            response_class: Temporalio::Api::WorkflowService::V1::ListScheduleMatchingTimesResponse,
            request:,
            rpc_options:
          )
        end

        # Calls WorkflowService.DeleteSchedule API call.
        #
        # @param request [Temporalio::Api::WorkflowService::V1::DeleteScheduleRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::WorkflowService::V1::DeleteScheduleResponse] API response.
        def delete_schedule(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'delete_schedule',
            request_class: Temporalio::Api::WorkflowService::V1::DeleteScheduleRequest,
            response_class: Temporalio::Api::WorkflowService::V1::DeleteScheduleResponse,
            request:,
            rpc_options:
          )
        end

        # Calls WorkflowService.ListSchedules API call.
        #
        # @param request [Temporalio::Api::WorkflowService::V1::ListSchedulesRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::WorkflowService::V1::ListSchedulesResponse] API response.
        def list_schedules(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'list_schedules',
            request_class: Temporalio::Api::WorkflowService::V1::ListSchedulesRequest,
            response_class: Temporalio::Api::WorkflowService::V1::ListSchedulesResponse,
            request:,
            rpc_options:
          )
        end

        # Calls WorkflowService.UpdateWorkerBuildIdCompatibility API call.
        #
        # @param request [Temporalio::Api::WorkflowService::V1::UpdateWorkerBuildIdCompatibilityRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::WorkflowService::V1::UpdateWorkerBuildIdCompatibilityResponse] API response.
        def update_worker_build_id_compatibility(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'update_worker_build_id_compatibility',
            request_class: Temporalio::Api::WorkflowService::V1::UpdateWorkerBuildIdCompatibilityRequest,
            response_class: Temporalio::Api::WorkflowService::V1::UpdateWorkerBuildIdCompatibilityResponse,
            request:,
            rpc_options:
          )
        end

        # Calls WorkflowService.GetWorkerBuildIdCompatibility API call.
        #
        # @param request [Temporalio::Api::WorkflowService::V1::GetWorkerBuildIdCompatibilityRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::WorkflowService::V1::GetWorkerBuildIdCompatibilityResponse] API response.
        def get_worker_build_id_compatibility(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'get_worker_build_id_compatibility',
            request_class: Temporalio::Api::WorkflowService::V1::GetWorkerBuildIdCompatibilityRequest,
            response_class: Temporalio::Api::WorkflowService::V1::GetWorkerBuildIdCompatibilityResponse,
            request:,
            rpc_options:
          )
        end

        # Calls WorkflowService.UpdateWorkerVersioningRules API call.
        #
        # @param request [Temporalio::Api::WorkflowService::V1::UpdateWorkerVersioningRulesRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::WorkflowService::V1::UpdateWorkerVersioningRulesResponse] API response.
        def update_worker_versioning_rules(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'update_worker_versioning_rules',
            request_class: Temporalio::Api::WorkflowService::V1::UpdateWorkerVersioningRulesRequest,
            response_class: Temporalio::Api::WorkflowService::V1::UpdateWorkerVersioningRulesResponse,
            request:,
            rpc_options:
          )
        end

        # Calls WorkflowService.GetWorkerVersioningRules API call.
        #
        # @param request [Temporalio::Api::WorkflowService::V1::GetWorkerVersioningRulesRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::WorkflowService::V1::GetWorkerVersioningRulesResponse] API response.
        def get_worker_versioning_rules(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'get_worker_versioning_rules',
            request_class: Temporalio::Api::WorkflowService::V1::GetWorkerVersioningRulesRequest,
            response_class: Temporalio::Api::WorkflowService::V1::GetWorkerVersioningRulesResponse,
            request:,
            rpc_options:
          )
        end

        # Calls WorkflowService.GetWorkerTaskReachability API call.
        #
        # @param request [Temporalio::Api::WorkflowService::V1::GetWorkerTaskReachabilityRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::WorkflowService::V1::GetWorkerTaskReachabilityResponse] API response.
        def get_worker_task_reachability(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'get_worker_task_reachability',
            request_class: Temporalio::Api::WorkflowService::V1::GetWorkerTaskReachabilityRequest,
            response_class: Temporalio::Api::WorkflowService::V1::GetWorkerTaskReachabilityResponse,
            request:,
            rpc_options:
          )
        end

        # Calls WorkflowService.DescribeDeployment API call.
        #
        # @param request [Temporalio::Api::WorkflowService::V1::DescribeDeploymentRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::WorkflowService::V1::DescribeDeploymentResponse] API response.
        def describe_deployment(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'describe_deployment',
            request_class: Temporalio::Api::WorkflowService::V1::DescribeDeploymentRequest,
            response_class: Temporalio::Api::WorkflowService::V1::DescribeDeploymentResponse,
            request:,
            rpc_options:
          )
        end

        # Calls WorkflowService.DescribeWorkerDeploymentVersion API call.
        #
        # @param request [Temporalio::Api::WorkflowService::V1::DescribeWorkerDeploymentVersionRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::WorkflowService::V1::DescribeWorkerDeploymentVersionResponse] API response.
        def describe_worker_deployment_version(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'describe_worker_deployment_version',
            request_class: Temporalio::Api::WorkflowService::V1::DescribeWorkerDeploymentVersionRequest,
            response_class: Temporalio::Api::WorkflowService::V1::DescribeWorkerDeploymentVersionResponse,
            request:,
            rpc_options:
          )
        end

        # Calls WorkflowService.ListDeployments API call.
        #
        # @param request [Temporalio::Api::WorkflowService::V1::ListDeploymentsRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::WorkflowService::V1::ListDeploymentsResponse] API response.
        def list_deployments(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'list_deployments',
            request_class: Temporalio::Api::WorkflowService::V1::ListDeploymentsRequest,
            response_class: Temporalio::Api::WorkflowService::V1::ListDeploymentsResponse,
            request:,
            rpc_options:
          )
        end

        # Calls WorkflowService.GetDeploymentReachability API call.
        #
        # @param request [Temporalio::Api::WorkflowService::V1::GetDeploymentReachabilityRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::WorkflowService::V1::GetDeploymentReachabilityResponse] API response.
        def get_deployment_reachability(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'get_deployment_reachability',
            request_class: Temporalio::Api::WorkflowService::V1::GetDeploymentReachabilityRequest,
            response_class: Temporalio::Api::WorkflowService::V1::GetDeploymentReachabilityResponse,
            request:,
            rpc_options:
          )
        end

        # Calls WorkflowService.GetCurrentDeployment API call.
        #
        # @param request [Temporalio::Api::WorkflowService::V1::GetCurrentDeploymentRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::WorkflowService::V1::GetCurrentDeploymentResponse] API response.
        def get_current_deployment(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'get_current_deployment',
            request_class: Temporalio::Api::WorkflowService::V1::GetCurrentDeploymentRequest,
            response_class: Temporalio::Api::WorkflowService::V1::GetCurrentDeploymentResponse,
            request:,
            rpc_options:
          )
        end

        # Calls WorkflowService.SetCurrentDeployment API call.
        #
        # @param request [Temporalio::Api::WorkflowService::V1::SetCurrentDeploymentRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::WorkflowService::V1::SetCurrentDeploymentResponse] API response.
        def set_current_deployment(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'set_current_deployment',
            request_class: Temporalio::Api::WorkflowService::V1::SetCurrentDeploymentRequest,
            response_class: Temporalio::Api::WorkflowService::V1::SetCurrentDeploymentResponse,
            request:,
            rpc_options:
          )
        end

        # Calls WorkflowService.SetWorkerDeploymentCurrentVersion API call.
        #
        # @param request [Temporalio::Api::WorkflowService::V1::SetWorkerDeploymentCurrentVersionRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::WorkflowService::V1::SetWorkerDeploymentCurrentVersionResponse] API response.
        def set_worker_deployment_current_version(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'set_worker_deployment_current_version',
            request_class: Temporalio::Api::WorkflowService::V1::SetWorkerDeploymentCurrentVersionRequest,
            response_class: Temporalio::Api::WorkflowService::V1::SetWorkerDeploymentCurrentVersionResponse,
            request:,
            rpc_options:
          )
        end

        # Calls WorkflowService.DescribeWorkerDeployment API call.
        #
        # @param request [Temporalio::Api::WorkflowService::V1::DescribeWorkerDeploymentRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::WorkflowService::V1::DescribeWorkerDeploymentResponse] API response.
        def describe_worker_deployment(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'describe_worker_deployment',
            request_class: Temporalio::Api::WorkflowService::V1::DescribeWorkerDeploymentRequest,
            response_class: Temporalio::Api::WorkflowService::V1::DescribeWorkerDeploymentResponse,
            request:,
            rpc_options:
          )
        end

        # Calls WorkflowService.DeleteWorkerDeployment API call.
        #
        # @param request [Temporalio::Api::WorkflowService::V1::DeleteWorkerDeploymentRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::WorkflowService::V1::DeleteWorkerDeploymentResponse] API response.
        def delete_worker_deployment(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'delete_worker_deployment',
            request_class: Temporalio::Api::WorkflowService::V1::DeleteWorkerDeploymentRequest,
            response_class: Temporalio::Api::WorkflowService::V1::DeleteWorkerDeploymentResponse,
            request:,
            rpc_options:
          )
        end

        # Calls WorkflowService.DeleteWorkerDeploymentVersion API call.
        #
        # @param request [Temporalio::Api::WorkflowService::V1::DeleteWorkerDeploymentVersionRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::WorkflowService::V1::DeleteWorkerDeploymentVersionResponse] API response.
        def delete_worker_deployment_version(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'delete_worker_deployment_version',
            request_class: Temporalio::Api::WorkflowService::V1::DeleteWorkerDeploymentVersionRequest,
            response_class: Temporalio::Api::WorkflowService::V1::DeleteWorkerDeploymentVersionResponse,
            request:,
            rpc_options:
          )
        end

        # Calls WorkflowService.SetWorkerDeploymentRampingVersion API call.
        #
        # @param request [Temporalio::Api::WorkflowService::V1::SetWorkerDeploymentRampingVersionRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::WorkflowService::V1::SetWorkerDeploymentRampingVersionResponse] API response.
        def set_worker_deployment_ramping_version(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'set_worker_deployment_ramping_version',
            request_class: Temporalio::Api::WorkflowService::V1::SetWorkerDeploymentRampingVersionRequest,
            response_class: Temporalio::Api::WorkflowService::V1::SetWorkerDeploymentRampingVersionResponse,
            request:,
            rpc_options:
          )
        end

        # Calls WorkflowService.ListWorkerDeployments API call.
        #
        # @param request [Temporalio::Api::WorkflowService::V1::ListWorkerDeploymentsRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::WorkflowService::V1::ListWorkerDeploymentsResponse] API response.
        def list_worker_deployments(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'list_worker_deployments',
            request_class: Temporalio::Api::WorkflowService::V1::ListWorkerDeploymentsRequest,
            response_class: Temporalio::Api::WorkflowService::V1::ListWorkerDeploymentsResponse,
            request:,
            rpc_options:
          )
        end

        # Calls WorkflowService.UpdateWorkerDeploymentVersionMetadata API call.
        #
        # @param request [Temporalio::Api::WorkflowService::V1::UpdateWorkerDeploymentVersionMetadataRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::WorkflowService::V1::UpdateWorkerDeploymentVersionMetadataResponse] API response.
        def update_worker_deployment_version_metadata(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'update_worker_deployment_version_metadata',
            request_class: Temporalio::Api::WorkflowService::V1::UpdateWorkerDeploymentVersionMetadataRequest,
            response_class: Temporalio::Api::WorkflowService::V1::UpdateWorkerDeploymentVersionMetadataResponse,
            request:,
            rpc_options:
          )
        end

        # Calls WorkflowService.SetWorkerDeploymentManager API call.
        #
        # @param request [Temporalio::Api::WorkflowService::V1::SetWorkerDeploymentManagerRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::WorkflowService::V1::SetWorkerDeploymentManagerResponse] API response.
        def set_worker_deployment_manager(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'set_worker_deployment_manager',
            request_class: Temporalio::Api::WorkflowService::V1::SetWorkerDeploymentManagerRequest,
            response_class: Temporalio::Api::WorkflowService::V1::SetWorkerDeploymentManagerResponse,
            request:,
            rpc_options:
          )
        end

        # Calls WorkflowService.UpdateWorkflowExecution API call.
        #
        # @param request [Temporalio::Api::WorkflowService::V1::UpdateWorkflowExecutionRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::WorkflowService::V1::UpdateWorkflowExecutionResponse] API response.
        def update_workflow_execution(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'update_workflow_execution',
            request_class: Temporalio::Api::WorkflowService::V1::UpdateWorkflowExecutionRequest,
            response_class: Temporalio::Api::WorkflowService::V1::UpdateWorkflowExecutionResponse,
            request:,
            rpc_options:
          )
        end

        # Calls WorkflowService.PollWorkflowExecutionUpdate API call.
        #
        # @param request [Temporalio::Api::WorkflowService::V1::PollWorkflowExecutionUpdateRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::WorkflowService::V1::PollWorkflowExecutionUpdateResponse] API response.
        def poll_workflow_execution_update(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'poll_workflow_execution_update',
            request_class: Temporalio::Api::WorkflowService::V1::PollWorkflowExecutionUpdateRequest,
            response_class: Temporalio::Api::WorkflowService::V1::PollWorkflowExecutionUpdateResponse,
            request:,
            rpc_options:
          )
        end

        # Calls WorkflowService.StartBatchOperation API call.
        #
        # @param request [Temporalio::Api::WorkflowService::V1::StartBatchOperationRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::WorkflowService::V1::StartBatchOperationResponse] API response.
        def start_batch_operation(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'start_batch_operation',
            request_class: Temporalio::Api::WorkflowService::V1::StartBatchOperationRequest,
            response_class: Temporalio::Api::WorkflowService::V1::StartBatchOperationResponse,
            request:,
            rpc_options:
          )
        end

        # Calls WorkflowService.StopBatchOperation API call.
        #
        # @param request [Temporalio::Api::WorkflowService::V1::StopBatchOperationRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::WorkflowService::V1::StopBatchOperationResponse] API response.
        def stop_batch_operation(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'stop_batch_operation',
            request_class: Temporalio::Api::WorkflowService::V1::StopBatchOperationRequest,
            response_class: Temporalio::Api::WorkflowService::V1::StopBatchOperationResponse,
            request:,
            rpc_options:
          )
        end

        # Calls WorkflowService.DescribeBatchOperation API call.
        #
        # @param request [Temporalio::Api::WorkflowService::V1::DescribeBatchOperationRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::WorkflowService::V1::DescribeBatchOperationResponse] API response.
        def describe_batch_operation(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'describe_batch_operation',
            request_class: Temporalio::Api::WorkflowService::V1::DescribeBatchOperationRequest,
            response_class: Temporalio::Api::WorkflowService::V1::DescribeBatchOperationResponse,
            request:,
            rpc_options:
          )
        end

        # Calls WorkflowService.ListBatchOperations API call.
        #
        # @param request [Temporalio::Api::WorkflowService::V1::ListBatchOperationsRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::WorkflowService::V1::ListBatchOperationsResponse] API response.
        def list_batch_operations(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'list_batch_operations',
            request_class: Temporalio::Api::WorkflowService::V1::ListBatchOperationsRequest,
            response_class: Temporalio::Api::WorkflowService::V1::ListBatchOperationsResponse,
            request:,
            rpc_options:
          )
        end

        # Calls WorkflowService.PollNexusTaskQueue API call.
        #
        # @param request [Temporalio::Api::WorkflowService::V1::PollNexusTaskQueueRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::WorkflowService::V1::PollNexusTaskQueueResponse] API response.
        def poll_nexus_task_queue(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'poll_nexus_task_queue',
            request_class: Temporalio::Api::WorkflowService::V1::PollNexusTaskQueueRequest,
            response_class: Temporalio::Api::WorkflowService::V1::PollNexusTaskQueueResponse,
            request:,
            rpc_options:
          )
        end

        # Calls WorkflowService.RespondNexusTaskCompleted API call.
        #
        # @param request [Temporalio::Api::WorkflowService::V1::RespondNexusTaskCompletedRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::WorkflowService::V1::RespondNexusTaskCompletedResponse] API response.
        def respond_nexus_task_completed(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'respond_nexus_task_completed',
            request_class: Temporalio::Api::WorkflowService::V1::RespondNexusTaskCompletedRequest,
            response_class: Temporalio::Api::WorkflowService::V1::RespondNexusTaskCompletedResponse,
            request:,
            rpc_options:
          )
        end

        # Calls WorkflowService.RespondNexusTaskFailed API call.
        #
        # @param request [Temporalio::Api::WorkflowService::V1::RespondNexusTaskFailedRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::WorkflowService::V1::RespondNexusTaskFailedResponse] API response.
        def respond_nexus_task_failed(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'respond_nexus_task_failed',
            request_class: Temporalio::Api::WorkflowService::V1::RespondNexusTaskFailedRequest,
            response_class: Temporalio::Api::WorkflowService::V1::RespondNexusTaskFailedResponse,
            request:,
            rpc_options:
          )
        end

        # Calls WorkflowService.UpdateActivityOptions API call.
        #
        # @param request [Temporalio::Api::WorkflowService::V1::UpdateActivityOptionsRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::WorkflowService::V1::UpdateActivityOptionsResponse] API response.
        def update_activity_options(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'update_activity_options',
            request_class: Temporalio::Api::WorkflowService::V1::UpdateActivityOptionsRequest,
            response_class: Temporalio::Api::WorkflowService::V1::UpdateActivityOptionsResponse,
            request:,
            rpc_options:
          )
        end

        # Calls WorkflowService.UpdateWorkflowExecutionOptions API call.
        #
        # @param request [Temporalio::Api::WorkflowService::V1::UpdateWorkflowExecutionOptionsRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::WorkflowService::V1::UpdateWorkflowExecutionOptionsResponse] API response.
        def update_workflow_execution_options(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'update_workflow_execution_options',
            request_class: Temporalio::Api::WorkflowService::V1::UpdateWorkflowExecutionOptionsRequest,
            response_class: Temporalio::Api::WorkflowService::V1::UpdateWorkflowExecutionOptionsResponse,
            request:,
            rpc_options:
          )
        end

        # Calls WorkflowService.PauseActivity API call.
        #
        # @param request [Temporalio::Api::WorkflowService::V1::PauseActivityRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::WorkflowService::V1::PauseActivityResponse] API response.
        def pause_activity(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'pause_activity',
            request_class: Temporalio::Api::WorkflowService::V1::PauseActivityRequest,
            response_class: Temporalio::Api::WorkflowService::V1::PauseActivityResponse,
            request:,
            rpc_options:
          )
        end

        # Calls WorkflowService.UnpauseActivity API call.
        #
        # @param request [Temporalio::Api::WorkflowService::V1::UnpauseActivityRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::WorkflowService::V1::UnpauseActivityResponse] API response.
        def unpause_activity(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'unpause_activity',
            request_class: Temporalio::Api::WorkflowService::V1::UnpauseActivityRequest,
            response_class: Temporalio::Api::WorkflowService::V1::UnpauseActivityResponse,
            request:,
            rpc_options:
          )
        end

        # Calls WorkflowService.ResetActivity API call.
        #
        # @param request [Temporalio::Api::WorkflowService::V1::ResetActivityRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::WorkflowService::V1::ResetActivityResponse] API response.
        def reset_activity(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'reset_activity',
            request_class: Temporalio::Api::WorkflowService::V1::ResetActivityRequest,
            response_class: Temporalio::Api::WorkflowService::V1::ResetActivityResponse,
            request:,
            rpc_options:
          )
        end

        # Calls WorkflowService.CreateWorkflowRule API call.
        #
        # @param request [Temporalio::Api::WorkflowService::V1::CreateWorkflowRuleRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::WorkflowService::V1::CreateWorkflowRuleResponse] API response.
        def create_workflow_rule(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'create_workflow_rule',
            request_class: Temporalio::Api::WorkflowService::V1::CreateWorkflowRuleRequest,
            response_class: Temporalio::Api::WorkflowService::V1::CreateWorkflowRuleResponse,
            request:,
            rpc_options:
          )
        end

        # Calls WorkflowService.DescribeWorkflowRule API call.
        #
        # @param request [Temporalio::Api::WorkflowService::V1::DescribeWorkflowRuleRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::WorkflowService::V1::DescribeWorkflowRuleResponse] API response.
        def describe_workflow_rule(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'describe_workflow_rule',
            request_class: Temporalio::Api::WorkflowService::V1::DescribeWorkflowRuleRequest,
            response_class: Temporalio::Api::WorkflowService::V1::DescribeWorkflowRuleResponse,
            request:,
            rpc_options:
          )
        end

        # Calls WorkflowService.DeleteWorkflowRule API call.
        #
        # @param request [Temporalio::Api::WorkflowService::V1::DeleteWorkflowRuleRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::WorkflowService::V1::DeleteWorkflowRuleResponse] API response.
        def delete_workflow_rule(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'delete_workflow_rule',
            request_class: Temporalio::Api::WorkflowService::V1::DeleteWorkflowRuleRequest,
            response_class: Temporalio::Api::WorkflowService::V1::DeleteWorkflowRuleResponse,
            request:,
            rpc_options:
          )
        end

        # Calls WorkflowService.ListWorkflowRules API call.
        #
        # @param request [Temporalio::Api::WorkflowService::V1::ListWorkflowRulesRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::WorkflowService::V1::ListWorkflowRulesResponse] API response.
        def list_workflow_rules(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'list_workflow_rules',
            request_class: Temporalio::Api::WorkflowService::V1::ListWorkflowRulesRequest,
            response_class: Temporalio::Api::WorkflowService::V1::ListWorkflowRulesResponse,
            request:,
            rpc_options:
          )
        end

        # Calls WorkflowService.TriggerWorkflowRule API call.
        #
        # @param request [Temporalio::Api::WorkflowService::V1::TriggerWorkflowRuleRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::WorkflowService::V1::TriggerWorkflowRuleResponse] API response.
        def trigger_workflow_rule(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'trigger_workflow_rule',
            request_class: Temporalio::Api::WorkflowService::V1::TriggerWorkflowRuleRequest,
            response_class: Temporalio::Api::WorkflowService::V1::TriggerWorkflowRuleResponse,
            request:,
            rpc_options:
          )
        end

        # Calls WorkflowService.RecordWorkerHeartbeat API call.
        #
        # @param request [Temporalio::Api::WorkflowService::V1::RecordWorkerHeartbeatRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::WorkflowService::V1::RecordWorkerHeartbeatResponse] API response.
        def record_worker_heartbeat(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'record_worker_heartbeat',
            request_class: Temporalio::Api::WorkflowService::V1::RecordWorkerHeartbeatRequest,
            response_class: Temporalio::Api::WorkflowService::V1::RecordWorkerHeartbeatResponse,
            request:,
            rpc_options:
          )
        end

        # Calls WorkflowService.ListWorkers API call.
        #
        # @param request [Temporalio::Api::WorkflowService::V1::ListWorkersRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::WorkflowService::V1::ListWorkersResponse] API response.
        def list_workers(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'list_workers',
            request_class: Temporalio::Api::WorkflowService::V1::ListWorkersRequest,
            response_class: Temporalio::Api::WorkflowService::V1::ListWorkersResponse,
            request:,
            rpc_options:
          )
        end

        # Calls WorkflowService.UpdateTaskQueueConfig API call.
        #
        # @param request [Temporalio::Api::WorkflowService::V1::UpdateTaskQueueConfigRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::WorkflowService::V1::UpdateTaskQueueConfigResponse] API response.
        def update_task_queue_config(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'update_task_queue_config',
            request_class: Temporalio::Api::WorkflowService::V1::UpdateTaskQueueConfigRequest,
            response_class: Temporalio::Api::WorkflowService::V1::UpdateTaskQueueConfigResponse,
            request:,
            rpc_options:
          )
        end

        # Calls WorkflowService.FetchWorkerConfig API call.
        #
        # @param request [Temporalio::Api::WorkflowService::V1::FetchWorkerConfigRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::WorkflowService::V1::FetchWorkerConfigResponse] API response.
        def fetch_worker_config(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'fetch_worker_config',
            request_class: Temporalio::Api::WorkflowService::V1::FetchWorkerConfigRequest,
            response_class: Temporalio::Api::WorkflowService::V1::FetchWorkerConfigResponse,
            request:,
            rpc_options:
          )
        end

        # Calls WorkflowService.UpdateWorkerConfig API call.
        #
        # @param request [Temporalio::Api::WorkflowService::V1::UpdateWorkerConfigRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::WorkflowService::V1::UpdateWorkerConfigResponse] API response.
        def update_worker_config(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'update_worker_config',
            request_class: Temporalio::Api::WorkflowService::V1::UpdateWorkerConfigRequest,
            response_class: Temporalio::Api::WorkflowService::V1::UpdateWorkerConfigResponse,
            request:,
            rpc_options:
          )
        end

        # Calls WorkflowService.DescribeWorker API call.
        #
        # @param request [Temporalio::Api::WorkflowService::V1::DescribeWorkerRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::WorkflowService::V1::DescribeWorkerResponse] API response.
        def describe_worker(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'describe_worker',
            request_class: Temporalio::Api::WorkflowService::V1::DescribeWorkerRequest,
            response_class: Temporalio::Api::WorkflowService::V1::DescribeWorkerResponse,
            request:,
            rpc_options:
          )
        end

        # Calls WorkflowService.PauseWorkflowExecution API call.
        #
        # @param request [Temporalio::Api::WorkflowService::V1::PauseWorkflowExecutionRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::WorkflowService::V1::PauseWorkflowExecutionResponse] API response.
        def pause_workflow_execution(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'pause_workflow_execution',
            request_class: Temporalio::Api::WorkflowService::V1::PauseWorkflowExecutionRequest,
            response_class: Temporalio::Api::WorkflowService::V1::PauseWorkflowExecutionResponse,
            request:,
            rpc_options:
          )
        end

        # Calls WorkflowService.UnpauseWorkflowExecution API call.
        #
        # @param request [Temporalio::Api::WorkflowService::V1::UnpauseWorkflowExecutionRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::WorkflowService::V1::UnpauseWorkflowExecutionResponse] API response.
        def unpause_workflow_execution(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'unpause_workflow_execution',
            request_class: Temporalio::Api::WorkflowService::V1::UnpauseWorkflowExecutionRequest,
            response_class: Temporalio::Api::WorkflowService::V1::UnpauseWorkflowExecutionResponse,
            request:,
            rpc_options:
          )
        end

        # Calls WorkflowService.StartActivityExecution API call.
        #
        # @param request [Temporalio::Api::WorkflowService::V1::StartActivityExecutionRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::WorkflowService::V1::StartActivityExecutionResponse] API response.
        def start_activity_execution(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'start_activity_execution',
            request_class: Temporalio::Api::WorkflowService::V1::StartActivityExecutionRequest,
            response_class: Temporalio::Api::WorkflowService::V1::StartActivityExecutionResponse,
            request:,
            rpc_options:
          )
        end

        # Calls WorkflowService.DescribeActivityExecution API call.
        #
        # @param request [Temporalio::Api::WorkflowService::V1::DescribeActivityExecutionRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::WorkflowService::V1::DescribeActivityExecutionResponse] API response.
        def describe_activity_execution(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'describe_activity_execution',
            request_class: Temporalio::Api::WorkflowService::V1::DescribeActivityExecutionRequest,
            response_class: Temporalio::Api::WorkflowService::V1::DescribeActivityExecutionResponse,
            request:,
            rpc_options:
          )
        end

        # Calls WorkflowService.PollActivityExecution API call.
        #
        # @param request [Temporalio::Api::WorkflowService::V1::PollActivityExecutionRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::WorkflowService::V1::PollActivityExecutionResponse] API response.
        def poll_activity_execution(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'poll_activity_execution',
            request_class: Temporalio::Api::WorkflowService::V1::PollActivityExecutionRequest,
            response_class: Temporalio::Api::WorkflowService::V1::PollActivityExecutionResponse,
            request:,
            rpc_options:
          )
        end

        # Calls WorkflowService.ListActivityExecutions API call.
        #
        # @param request [Temporalio::Api::WorkflowService::V1::ListActivityExecutionsRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::WorkflowService::V1::ListActivityExecutionsResponse] API response.
        def list_activity_executions(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'list_activity_executions',
            request_class: Temporalio::Api::WorkflowService::V1::ListActivityExecutionsRequest,
            response_class: Temporalio::Api::WorkflowService::V1::ListActivityExecutionsResponse,
            request:,
            rpc_options:
          )
        end

        # Calls WorkflowService.CountActivityExecutions API call.
        #
        # @param request [Temporalio::Api::WorkflowService::V1::CountActivityExecutionsRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::WorkflowService::V1::CountActivityExecutionsResponse] API response.
        def count_activity_executions(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'count_activity_executions',
            request_class: Temporalio::Api::WorkflowService::V1::CountActivityExecutionsRequest,
            response_class: Temporalio::Api::WorkflowService::V1::CountActivityExecutionsResponse,
            request:,
            rpc_options:
          )
        end

        # Calls WorkflowService.RequestCancelActivityExecution API call.
        #
        # @param request [Temporalio::Api::WorkflowService::V1::RequestCancelActivityExecutionRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::WorkflowService::V1::RequestCancelActivityExecutionResponse] API response.
        def request_cancel_activity_execution(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'request_cancel_activity_execution',
            request_class: Temporalio::Api::WorkflowService::V1::RequestCancelActivityExecutionRequest,
            response_class: Temporalio::Api::WorkflowService::V1::RequestCancelActivityExecutionResponse,
            request:,
            rpc_options:
          )
        end

        # Calls WorkflowService.TerminateActivityExecution API call.
        #
        # @param request [Temporalio::Api::WorkflowService::V1::TerminateActivityExecutionRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::WorkflowService::V1::TerminateActivityExecutionResponse] API response.
        def terminate_activity_execution(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'terminate_activity_execution',
            request_class: Temporalio::Api::WorkflowService::V1::TerminateActivityExecutionRequest,
            response_class: Temporalio::Api::WorkflowService::V1::TerminateActivityExecutionResponse,
            request:,
            rpc_options:
          )
        end

        # Calls WorkflowService.DeleteActivityExecution API call.
        #
        # @param request [Temporalio::Api::WorkflowService::V1::DeleteActivityExecutionRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::WorkflowService::V1::DeleteActivityExecutionResponse] API response.
        def delete_activity_execution(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'delete_activity_execution',
            request_class: Temporalio::Api::WorkflowService::V1::DeleteActivityExecutionRequest,
            response_class: Temporalio::Api::WorkflowService::V1::DeleteActivityExecutionResponse,
            request:,
            rpc_options:
          )
        end
      end
    end
  end
end
