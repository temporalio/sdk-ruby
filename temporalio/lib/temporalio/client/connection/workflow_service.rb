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
      end
    end
  end
end
