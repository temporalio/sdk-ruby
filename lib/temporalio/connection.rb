require 'temporal/api/workflowservice/v1/request_response_pb'
require 'temporalio/bridge'
require 'temporalio/errors'
require 'temporalio/runtime'
require 'uri'

module Temporalio
  # A connection to the Temporal server.
  #
  # This is used to instantiate a {Temporalio::Client} or a {Temporalio::Worker}. But it also can be used for a direct
  # interaction with the API.
  class Connection
    CLIENT_NAME = 'temporal-ruby'.freeze

    # @api private
    attr_reader :core_connection

    # @param host [String] `host:port` for the Temporal server. For local development, this is
    #   often `"localhost:7233"`.
    def initialize(host)
      runtime = Temporalio::Runtime.instance
      @core_connection = Temporalio::Bridge::Connection.connect(
        runtime.core_runtime, parse_url(host), Temporalio.identity, CLIENT_NAME, Temporalio::VERSION,
      )
    end

    # @param request [Temporalio::Api::WorkflowService::V1::RegisterNamespaceRequest]
    # @param metadata [Hash<String, String>] Headers used on the RPC call.
    #   Keys here override client-level RPC metadata keys.
    # @param timeout [Integer] Optional RPC deadline to set for each RPC call.
    #
    # @return [Temporalio::Api::WorkflowService::V1::RegisterNamespaceResponse]
    def register_namespace(request, metadata: {}, timeout: nil)
      encoded = Temporalio::Api::WorkflowService::V1::RegisterNamespaceRequest.encode(request)
      response = core_connection.call(:register_namespace, encoded, metadata, timeout)

      Temporalio::Api::WorkflowService::V1::RegisterNamespaceResponse.decode(response)
    end

    # @param request [Temporalio::Api::WorkflowService::V1::DescribeNamespaceRequest]
    # @param metadata [Hash<String, String>] Headers used on the RPC call.
    #   Keys here override client-level RPC metadata keys.
    # @param timeout [Integer] Optional RPC deadline to set for each RPC call.
    #
    # @return [Temporalio::Api::WorkflowService::V1::DescribeNamespaceResponse]
    def describe_namespace(request, metadata: {}, timeout: nil)
      encoded = Temporalio::Api::WorkflowService::V1::DescribeNamespaceRequest.encode(request)
      response = core_connection.call(:describe_namespace, encoded, metadata, timeout)

      Temporalio::Api::WorkflowService::V1::DescribeNamespaceResponse.decode(response)
    end

    # @param request [Temporalio::Api::WorkflowService::V1::ListNamespacesRequest]
    # @param metadata [Hash<String, String>] Headers used on the RPC call.
    #   Keys here override client-level RPC metadata keys.
    # @param timeout [Integer] Optional RPC deadline to set for each RPC call.
    #
    # @return [Temporalio::Api::WorkflowService::V1::ListNamespacesResponse]
    def list_namespaces(request, metadata: {}, timeout: nil)
      encoded = Temporalio::Api::WorkflowService::V1::ListNamespacesRequest.encode(request)
      response = core_connection.call(:list_namespaces, encoded, metadata, timeout)

      Temporalio::Api::WorkflowService::V1::ListNamespacesResponse.decode(response)
    end

    # @param request [Temporalio::Api::WorkflowService::V1::UpdateNamespaceRequest]
    # @param metadata [Hash<String, String>] Headers used on the RPC call.
    #   Keys here override client-level RPC metadata keys.
    # @param timeout [Integer] Optional RPC deadline to set for each RPC call.
    #
    # @return [Temporalio::Api::WorkflowService::V1::UpdateNamespaceResponse]
    def update_namespace(request, metadata: {}, timeout: nil)
      encoded = Temporalio::Api::WorkflowService::V1::UpdateNamespaceRequest.encode(request)
      response = core_connection.call(:update_namespace, encoded, metadata, timeout)

      Temporalio::Api::WorkflowService::V1::UpdateNamespaceResponse.decode(response)
    end

    # @param request [Temporalio::Api::WorkflowService::V1::DeprecateNamespaceRequest]
    # @param metadata [Hash<String, String>] Headers used on the RPC call.
    #   Keys here override client-level RPC metadata keys.
    # @param timeout [Integer] Optional RPC deadline to set for each RPC call.
    #
    # @return [Temporalio::Api::WorkflowService::V1::DeprecateNamespaceResponse]
    def deprecate_namespace(request, metadata: {}, timeout: nil)
      encoded = Temporalio::Api::WorkflowService::V1::DeprecateNamespaceRequest.encode(request)
      response = core_connection.call(:deprecate_namespace, encoded, metadata, timeout)

      Temporalio::Api::WorkflowService::V1::DeprecateNamespaceResponse.decode(response)
    end

    # @param request [Temporalio::Api::WorkflowService::V1::StartWorkflowExecutionRequest]
    # @param metadata [Hash<String, String>] Headers used on the RPC call.
    #   Keys here override client-level RPC metadata keys.
    # @param timeout [Integer] Optional RPC deadline to set for each RPC call.
    #
    # @return [Temporalio::Api::WorkflowService::V1::StartWorkflowExecutionResponse]
    def start_workflow_execution(request, metadata: {}, timeout: nil)
      encoded = Temporalio::Api::WorkflowService::V1::StartWorkflowExecutionRequest.encode(request)
      response = core_connection.call(:start_workflow_execution, encoded, metadata, timeout)

      Temporalio::Api::WorkflowService::V1::StartWorkflowExecutionResponse.decode(response)
    end

    # @param request [Temporalio::Api::WorkflowService::V1::GetWorkflowExecutionHistoryRequest]
    # @param metadata [Hash<String, String>] Headers used on the RPC call.
    #   Keys here override client-level RPC metadata keys.
    # @param timeout [Integer] Optional RPC deadline to set for each RPC call.
    #
    # @return [Temporalio::Api::WorkflowService::V1::GetWorkflowExecutionHistoryResponse]
    def get_workflow_execution_history(request, metadata: {}, timeout: nil)
      encoded = Temporalio::Api::WorkflowService::V1::GetWorkflowExecutionHistoryRequest.encode(request)
      response = core_connection.call(:get_workflow_execution_history, encoded, metadata, timeout)

      Temporalio::Api::WorkflowService::V1::GetWorkflowExecutionHistoryResponse.decode(response)
    end

    # @param request [Temporalio::Api::WorkflowService::V1::GetWorkflowExecutionHistoryReverseRequest]
    # @param metadata [Hash<String, String>] Headers used on the RPC call.
    #   Keys here override client-level RPC metadata keys.
    # @param timeout [Integer] Optional RPC deadline to set for each RPC call.
    #
    # @return [Temporalio::Api::WorkflowService::V1::GetWorkflowExecutionHistoryReverseResponse]
    def get_workflow_execution_history_reverse(request, metadata: {}, timeout: nil)
      encoded = Temporalio::Api::WorkflowService::V1::GetWorkflowExecutionHistoryReverseRequest.encode(request)
      response = core_connection.call(:get_workflow_execution_history_reverse, encoded, metadata, timeout)

      Temporalio::Api::WorkflowService::V1::GetWorkflowExecutionHistoryReverseResponse.decode(response)
    end

    # @param request [Temporalio::Api::WorkflowService::V1::PollWorkflowTaskQueueRequest]
    # @param metadata [Hash<String, String>] Headers used on the RPC call.
    #   Keys here override client-level RPC metadata keys.
    # @param timeout [Integer] Optional RPC deadline to set for each RPC call.
    #
    # @return [Temporalio::Api::WorkflowService::V1::PollWorkflowTaskQueueResponse]
    def poll_workflow_task_queue(request, metadata: {}, timeout: nil)
      encoded = Temporalio::Api::WorkflowService::V1::PollWorkflowTaskQueueRequest.encode(request)
      response = core_connection.call(:poll_workflow_task_queue, encoded, metadata, timeout)

      Temporalio::Api::WorkflowService::V1::PollWorkflowTaskQueueResponse.decode(response)
    end

    # @param request [Temporalio::Api::WorkflowService::V1::RespondWorkflowTaskCompletedRequest]
    # @param metadata [Hash<String, String>] Headers used on the RPC call.
    #   Keys here override client-level RPC metadata keys.
    # @param timeout [Integer] Optional RPC deadline to set for each RPC call.
    #
    # @return [Temporalio::Api::WorkflowService::V1::RespondWorkflowTaskCompletedResponse]
    def respond_workflow_task_completed(request, metadata: {}, timeout: nil)
      encoded = Temporalio::Api::WorkflowService::V1::RespondWorkflowTaskCompletedRequest.encode(request)
      response = core_connection.call(:respond_workflow_task_completed, encoded, metadata, timeout)

      Temporalio::Api::WorkflowService::V1::RespondWorkflowTaskCompletedResponse.decode(response)
    end

    # @param request [Temporalio::Api::WorkflowService::V1::RespondWorkflowTaskFailedRequest]
    # @param metadata [Hash<String, String>] Headers used on the RPC call.
    #   Keys here override client-level RPC metadata keys.
    # @param timeout [Integer] Optional RPC deadline to set for each RPC call.
    #
    # @return [Temporalio::Api::WorkflowService::V1::RespondWorkflowTaskFailedResponse]
    def respond_workflow_task_failed(request, metadata: {}, timeout: nil)
      encoded = Temporalio::Api::WorkflowService::V1::RespondWorkflowTaskFailedRequest.encode(request)
      response = core_connection.call(:respond_workflow_task_failed, encoded, metadata, timeout)

      Temporalio::Api::WorkflowService::V1::RespondWorkflowTaskFailedResponse.decode(response)
    end

    # @param request [Temporalio::Api::WorkflowService::V1::PollActivityTaskQueueRequest]
    # @param metadata [Hash<String, String>] Headers used on the RPC call.
    #   Keys here override client-level RPC metadata keys.
    # @param timeout [Integer] Optional RPC deadline to set for each RPC call.
    #
    # @return [Temporalio::Api::WorkflowService::V1::PollActivityTaskQueueResponse]
    def poll_activity_task_queue(request, metadata: {}, timeout: nil)
      encoded = Temporalio::Api::WorkflowService::V1::PollActivityTaskQueueRequest.encode(request)
      response = core_connection.call(:poll_activity_task_queue, encoded, metadata, timeout)

      Temporalio::Api::WorkflowService::V1::PollActivityTaskQueueResponse.decode(response)
    end

    # @param request [Temporalio::Api::WorkflowService::V1::RecordActivityTaskHeartbeatRequest]
    # @param metadata [Hash<String, String>] Headers used on the RPC call.
    #   Keys here override client-level RPC metadata keys.
    # @param timeout [Integer] Optional RPC deadline to set for each RPC call.
    #
    # @return [Temporalio::Api::WorkflowService::V1::RecordActivityTaskHeartbeatResponse]
    def record_activity_task_heartbeat(request, metadata: {}, timeout: nil)
      encoded = Temporalio::Api::WorkflowService::V1::RecordActivityTaskHeartbeatRequest.encode(request)
      response = core_connection.call(:record_activity_task_heartbeat, encoded, metadata, timeout)

      Temporalio::Api::WorkflowService::V1::RecordActivityTaskHeartbeatResponse.decode(response)
    end

    # @param request [Temporalio::Api::WorkflowService::V1::RecordActivityTaskHeartbeatByIdRequest]
    # @param metadata [Hash<String, String>] Headers used on the RPC call.
    #   Keys here override client-level RPC metadata keys.
    # @param timeout [Integer] Optional RPC deadline to set for each RPC call.
    #
    # @return [Temporalio::Api::WorkflowService::V1::RecordActivityTaskHeartbeatByIdResponse]
    def record_activity_task_heartbeat_by_id(request, metadata: {}, timeout: nil)
      encoded = Temporalio::Api::WorkflowService::V1::RecordActivityTaskHeartbeatByIdRequest.encode(request)
      response = core_connection.call(:record_activity_task_heartbeat_by_id, encoded, metadata, timeout)

      Temporalio::Api::WorkflowService::V1::RecordActivityTaskHeartbeatByIdResponse.decode(response)
    end

    # @param request [Temporalio::Api::WorkflowService::V1::RespondActivityTaskCompletedRequest]
    # @param metadata [Hash<String, String>] Headers used on the RPC call.
    #   Keys here override client-level RPC metadata keys.
    # @param timeout [Integer] Optional RPC deadline to set for each RPC call.
    #
    # @return [Temporalio::Api::WorkflowService::V1::RespondActivityTaskCompletedResponse]
    def respond_activity_task_completed(request, metadata: {}, timeout: nil)
      encoded = Temporalio::Api::WorkflowService::V1::RespondActivityTaskCompletedRequest.encode(request)
      response = core_connection.call(:respond_activity_task_completed, encoded, metadata, timeout)

      Temporalio::Api::WorkflowService::V1::RespondActivityTaskCompletedResponse.decode(response)
    end

    # @param request [Temporalio::Api::WorkflowService::V1::RespondActivityTaskCompletedByIdRequest]
    # @param metadata [Hash<String, String>] Headers used on the RPC call.
    #   Keys here override client-level RPC metadata keys.
    # @param timeout [Integer] Optional RPC deadline to set for each RPC call.
    #
    # @return [Temporalio::Api::WorkflowService::V1::RespondActivityTaskCompletedByIdResponse]
    def respond_activity_task_completed_by_id(request, metadata: {}, timeout: nil)
      encoded = Temporalio::Api::WorkflowService::V1::RespondActivityTaskCompletedByIdRequest.encode(request)
      response = core_connection.call(:respond_activity_task_completed_by_id, encoded, metadata, timeout)

      Temporalio::Api::WorkflowService::V1::RespondActivityTaskCompletedByIdResponse.decode(response)
    end

    # @param request [Temporalio::Api::WorkflowService::V1::RespondActivityTaskFailedRequest]
    # @param metadata [Hash<String, String>] Headers used on the RPC call.
    #   Keys here override client-level RPC metadata keys.
    # @param timeout [Integer] Optional RPC deadline to set for each RPC call.
    #
    # @return [Temporalio::Api::WorkflowService::V1::RespondActivityTaskFailedResponse]
    def respond_activity_task_failed(request, metadata: {}, timeout: nil)
      encoded = Temporalio::Api::WorkflowService::V1::RespondActivityTaskFailedRequest.encode(request)
      response = core_connection.call(:respond_activity_task_failed, encoded, metadata, timeout)

      Temporalio::Api::WorkflowService::V1::RespondActivityTaskFailedResponse.decode(response)
    end

    # @param request [Temporalio::Api::WorkflowService::V1::RespondActivityTaskFailedByIdRequest]
    # @param metadata [Hash<String, String>] Headers used on the RPC call.
    #   Keys here override client-level RPC metadata keys.
    # @param timeout [Integer] Optional RPC deadline to set for each RPC call.
    #
    # @return [Temporalio::Api::WorkflowService::V1::RespondActivityTaskFailedByIdResponse]
    def respond_activity_task_failed_by_id(request, metadata: {}, timeout: nil)
      encoded = Temporalio::Api::WorkflowService::V1::RespondActivityTaskFailedByIdRequest.encode(request)
      response = core_connection.call(:respond_activity_task_failed_by_id, encoded, metadata, timeout)

      Temporalio::Api::WorkflowService::V1::RespondActivityTaskFailedByIdResponse.decode(response)
    end

    # @param request [Temporalio::Api::WorkflowService::V1::RespondActivityTaskCanceledRequest]
    # @param metadata [Hash<String, String>] Headers used on the RPC call.
    #   Keys here override client-level RPC metadata keys.
    # @param timeout [Integer] Optional RPC deadline to set for each RPC call.
    #
    # @return [Temporalio::Api::WorkflowService::V1::RespondActivityTaskCanceledResponse]
    def respond_activity_task_canceled(request, metadata: {}, timeout: nil)
      encoded = Temporalio::Api::WorkflowService::V1::RespondActivityTaskCanceledRequest.encode(request)
      response = core_connection.call(:respond_activity_task_canceled, encoded, metadata, timeout)

      Temporalio::Api::WorkflowService::V1::RespondActivityTaskCanceledResponse.decode(response)
    end

    # @param request [Temporalio::Api::WorkflowService::V1::RespondActivityTaskCanceledByIdRequest]
    # @param metadata [Hash<String, String>] Headers used on the RPC call.
    #   Keys here override client-level RPC metadata keys.
    # @param timeout [Integer] Optional RPC deadline to set for each RPC call.
    #
    # @return [Temporalio::Api::WorkflowService::V1::RespondActivityTaskCanceledByIdResponse]
    def respond_activity_task_canceled_by_id(request, metadata: {}, timeout: nil)
      encoded = Temporalio::Api::WorkflowService::V1::RespondActivityTaskCanceledByIdRequest.encode(request)
      response = core_connection.call(:respond_activity_task_canceled_by_id, encoded, metadata, timeout)

      Temporalio::Api::WorkflowService::V1::RespondActivityTaskCanceledByIdResponse.decode(response)
    end

    # @param request [Temporalio::Api::WorkflowService::V1::RequestCancelWorkflowExecutionRequest]
    # @param metadata [Hash<String, String>] Headers used on the RPC call.
    #   Keys here override client-level RPC metadata keys.
    # @param timeout [Integer] Optional RPC deadline to set for each RPC call.
    #
    # @return [Temporalio::Api::WorkflowService::V1::RequestCancelWorkflowExecutionResponse]
    def request_cancel_workflow_execution(request, metadata: {}, timeout: nil)
      encoded = Temporalio::Api::WorkflowService::V1::RequestCancelWorkflowExecutionRequest.encode(request)
      response = core_connection.call(:request_cancel_workflow_execution, encoded, metadata, timeout)

      Temporalio::Api::WorkflowService::V1::RequestCancelWorkflowExecutionResponse.decode(response)
    end

    # @param request [Temporalio::Api::WorkflowService::V1::SignalWorkflowExecutionRequest]
    # @param metadata [Hash<String, String>] Headers used on the RPC call.
    #   Keys here override client-level RPC metadata keys.
    # @param timeout [Integer] Optional RPC deadline to set for each RPC call.
    #
    # @return [Temporalio::Api::WorkflowService::V1::SignalWorkflowExecutionResponse]
    def signal_workflow_execution(request, metadata: {}, timeout: nil)
      encoded = Temporalio::Api::WorkflowService::V1::SignalWorkflowExecutionRequest.encode(request)
      response = core_connection.call(:signal_workflow_execution, encoded, metadata, timeout)

      Temporalio::Api::WorkflowService::V1::SignalWorkflowExecutionResponse.decode(response)
    end

    # @param request [Temporalio::Api::WorkflowService::V1::SignalWithStartWorkflowExecutionRequest]
    # @param metadata [Hash<String, String>] Headers used on the RPC call.
    #   Keys here override client-level RPC metadata keys.
    # @param timeout [Integer] Optional RPC deadline to set for each RPC call.
    #
    # @return [Temporalio::Api::WorkflowService::V1::SignalWithStartWorkflowExecutionResponse]
    def signal_with_start_workflow_execution(request, metadata: {}, timeout: nil)
      encoded = Temporalio::Api::WorkflowService::V1::SignalWithStartWorkflowExecutionRequest.encode(request)
      response = core_connection.call(:signal_with_start_workflow_execution, encoded, metadata, timeout)

      Temporalio::Api::WorkflowService::V1::SignalWithStartWorkflowExecutionResponse.decode(response)
    end

    # @param request [Temporalio::Api::WorkflowService::V1::ResetWorkflowExecutionRequest]
    # @param metadata [Hash<String, String>] Headers used on the RPC call.
    #   Keys here override client-level RPC metadata keys.
    # @param timeout [Integer] Optional RPC deadline to set for each RPC call.
    #
    # @return [Temporalio::Api::WorkflowService::V1::ResetWorkflowExecutionResponse]
    def reset_workflow_execution(request, metadata: {}, timeout: nil)
      encoded = Temporalio::Api::WorkflowService::V1::ResetWorkflowExecutionRequest.encode(request)
      response = core_connection.call(:reset_workflow_execution, encoded, metadata, timeout)

      Temporalio::Api::WorkflowService::V1::ResetWorkflowExecutionResponse.decode(response)
    end

    # @param request [Temporalio::Api::WorkflowService::V1::TerminateWorkflowExecutionRequest]
    # @param metadata [Hash<String, String>] Headers used on the RPC call.
    #   Keys here override client-level RPC metadata keys.
    # @param timeout [Integer] Optional RPC deadline to set for each RPC call.
    #
    # @return [Temporalio::Api::WorkflowService::V1::TerminateWorkflowExecutionResponse]
    def terminate_workflow_execution(request, metadata: {}, timeout: nil)
      encoded = Temporalio::Api::WorkflowService::V1::TerminateWorkflowExecutionRequest.encode(request)
      response = core_connection.call(:terminate_workflow_execution, encoded, metadata, timeout)

      Temporalio::Api::WorkflowService::V1::TerminateWorkflowExecutionResponse.decode(response)
    end

    # @param request [Temporalio::Api::WorkflowService::V1::DeleteWorkflowExecutionRequest]
    # @param metadata [Hash<String, String>] Headers used on the RPC call.
    #   Keys here override client-level RPC metadata keys.
    # @param timeout [Integer] Optional RPC deadline to set for each RPC call.
    #
    # @return [Temporalio::Api::WorkflowService::V1::DeleteWorkflowExecutionResponse]
    def delete_workflow_execution(request, metadata: {}, timeout: nil)
      encoded = Temporalio::Api::WorkflowService::V1::DeleteWorkflowExecutionRequest.encode(request)
      response = core_connection.call(:delete_workflow_execution, encoded, metadata, timeout)

      Temporalio::Api::WorkflowService::V1::DeleteWorkflowExecutionResponse.decode(response)
    end

    # @param request [Temporalio::Api::WorkflowService::V1::ListOpenWorkflowExecutionsRequest]
    # @param metadata [Hash<String, String>] Headers used on the RPC call.
    #   Keys here override client-level RPC metadata keys.
    # @param timeout [Integer] Optional RPC deadline to set for each RPC call.
    #
    # @return [Temporalio::Api::WorkflowService::V1::ListOpenWorkflowExecutionsResponse]
    def list_open_workflow_executions(request, metadata: {}, timeout: nil)
      encoded = Temporalio::Api::WorkflowService::V1::ListOpenWorkflowExecutionsRequest.encode(request)
      response = core_connection.call(:list_open_workflow_executions, encoded, metadata, timeout)

      Temporalio::Api::WorkflowService::V1::ListOpenWorkflowExecutionsResponse.decode(response)
    end

    # @param request [Temporalio::Api::WorkflowService::V1::ListClosedWorkflowExecutionsRequest]
    # @param metadata [Hash<String, String>] Headers used on the RPC call.
    #   Keys here override client-level RPC metadata keys.
    # @param timeout [Integer] Optional RPC deadline to set for each RPC call.
    #
    # @return [Temporalio::Api::WorkflowService::V1::ListClosedWorkflowExecutionsResponse]
    def list_closed_workflow_executions(request, metadata: {}, timeout: nil)
      encoded = Temporalio::Api::WorkflowService::V1::ListClosedWorkflowExecutionsRequest.encode(request)
      response = core_connection.call(:list_closed_workflow_executions, encoded, metadata, timeout)

      Temporalio::Api::WorkflowService::V1::ListClosedWorkflowExecutionsResponse.decode(response)
    end

    # @param request [Temporalio::Api::WorkflowService::V1::ListWorkflowExecutionsRequest]
    # @param metadata [Hash<String, String>] Headers used on the RPC call.
    #   Keys here override client-level RPC metadata keys.
    # @param timeout [Integer] Optional RPC deadline to set for each RPC call.
    #
    # @return [Temporalio::Api::WorkflowService::V1::ListWorkflowExecutionsResponse]
    def list_workflow_executions(request, metadata: {}, timeout: nil)
      encoded = Temporalio::Api::WorkflowService::V1::ListWorkflowExecutionsRequest.encode(request)
      response = core_connection.call(:list_workflow_executions, encoded, metadata, timeout)

      Temporalio::Api::WorkflowService::V1::ListWorkflowExecutionsResponse.decode(response)
    end

    # @param request [Temporalio::Api::WorkflowService::V1::ListArchivedWorkflowExecutionsRequest]
    # @param metadata [Hash<String, String>] Headers used on the RPC call.
    #   Keys here override client-level RPC metadata keys.
    # @param timeout [Integer] Optional RPC deadline to set for each RPC call.
    #
    # @return [Temporalio::Api::WorkflowService::V1::ListArchivedWorkflowExecutionsResponse]
    def list_archived_workflow_executions(request, metadata: {}, timeout: nil)
      encoded = Temporalio::Api::WorkflowService::V1::ListArchivedWorkflowExecutionsRequest.encode(request)
      response = core_connection.call(:list_archived_workflow_executions, encoded, metadata, timeout)

      Temporalio::Api::WorkflowService::V1::ListArchivedWorkflowExecutionsResponse.decode(response)
    end

    # @param request [Temporalio::Api::WorkflowService::V1::ScanWorkflowExecutionsRequest]
    # @param metadata [Hash<String, String>] Headers used on the RPC call.
    #   Keys here override client-level RPC metadata keys.
    # @param timeout [Integer] Optional RPC deadline to set for each RPC call.
    #
    # @return [Temporalio::Api::WorkflowService::V1::ScanWorkflowExecutionsResponse]
    def scan_workflow_executions(request, metadata: {}, timeout: nil)
      encoded = Temporalio::Api::WorkflowService::V1::ScanWorkflowExecutionsRequest.encode(request)
      response = core_connection.call(:scan_workflow_executions, encoded, metadata, timeout)

      Temporalio::Api::WorkflowService::V1::ScanWorkflowExecutionsResponse.decode(response)
    end

    # @param request [Temporalio::Api::WorkflowService::V1::CountWorkflowExecutionsRequest]
    # @param metadata [Hash<String, String>] Headers used on the RPC call.
    #   Keys here override client-level RPC metadata keys.
    # @param timeout [Integer] Optional RPC deadline to set for each RPC call.
    #
    # @return [Temporalio::Api::WorkflowService::V1::CountWorkflowExecutionsResponse]
    def count_workflow_executions(request, metadata: {}, timeout: nil)
      encoded = Temporalio::Api::WorkflowService::V1::CountWorkflowExecutionsRequest.encode(request)
      response = core_connection.call(:count_workflow_executions, encoded, metadata, timeout)

      Temporalio::Api::WorkflowService::V1::CountWorkflowExecutionsResponse.decode(response)
    end

    # @param request [Temporalio::Api::WorkflowService::V1::GetSearchAttributesRequest]
    # @param metadata [Hash<String, String>] Headers used on the RPC call.
    #   Keys here override client-level RPC metadata keys.
    # @param timeout [Integer] Optional RPC deadline to set for each RPC call.
    #
    # @return [Temporalio::Api::WorkflowService::V1::GetSearchAttributesResponse]
    def get_search_attributes(request, metadata: {}, timeout: nil)
      encoded = Temporalio::Api::WorkflowService::V1::GetSearchAttributesRequest.encode(request)
      response = core_connection.call(:get_search_attributes, encoded, metadata, timeout)

      Temporalio::Api::WorkflowService::V1::GetSearchAttributesResponse.decode(response)
    end

    # @param request [Temporalio::Api::WorkflowService::V1::RespondQueryTaskCompletedRequest]
    # @param metadata [Hash<String, String>] Headers used on the RPC call.
    #   Keys here override client-level RPC metadata keys.
    # @param timeout [Integer] Optional RPC deadline to set for each RPC call.
    #
    # @return [Temporalio::Api::WorkflowService::V1::RespondQueryTaskCompletedResponse]
    def respond_query_task_completed(request, metadata: {}, timeout: nil)
      encoded = Temporalio::Api::WorkflowService::V1::RespondQueryTaskCompletedRequest.encode(request)
      response = core_connection.call(:respond_query_task_completed, encoded, metadata, timeout)

      Temporalio::Api::WorkflowService::V1::RespondQueryTaskCompletedResponse.decode(response)
    end

    # @param request [Temporalio::Api::WorkflowService::V1::ResetStickyTaskQueueRequest]
    # @param metadata [Hash<String, String>] Headers used on the RPC call.
    #   Keys here override client-level RPC metadata keys.
    # @param timeout [Integer] Optional RPC deadline to set for each RPC call.
    #
    # @return [Temporalio::Api::WorkflowService::V1::ResetStickyTaskQueueResponse]
    def reset_sticky_task_queue(request, metadata: {}, timeout: nil)
      encoded = Temporalio::Api::WorkflowService::V1::ResetStickyTaskQueueRequest.encode(request)
      response = core_connection.call(:reset_sticky_task_queue, encoded, metadata, timeout)

      Temporalio::Api::WorkflowService::V1::ResetStickyTaskQueueResponse.decode(response)
    end

    # @param request [Temporalio::Api::WorkflowService::V1::QueryWorkflowRequest]
    # @param metadata [Hash<String, String>] Headers used on the RPC call.
    #   Keys here override client-level RPC metadata keys.
    # @param timeout [Integer] Optional RPC deadline to set for each RPC call.
    #
    # @return [Temporalio::Api::WorkflowService::V1::QueryWorkflowResponse]
    def query_workflow(request, metadata: {}, timeout: nil)
      encoded = Temporalio::Api::WorkflowService::V1::QueryWorkflowRequest.encode(request)
      response = core_connection.call(:query_workflow, encoded, metadata, timeout)

      Temporalio::Api::WorkflowService::V1::QueryWorkflowResponse.decode(response)
    end

    # @param request [Temporalio::Api::WorkflowService::V1::DescribeWorkflowExecutionRequest]
    # @param metadata [Hash<String, String>] Headers used on the RPC call.
    #   Keys here override client-level RPC metadata keys.
    # @param timeout [Integer] Optional RPC deadline to set for each RPC call.
    #
    # @return [Temporalio::Api::WorkflowService::V1::DescribeWorkflowExecutionResponse]
    def describe_workflow_execution(request, metadata: {}, timeout: nil)
      encoded = Temporalio::Api::WorkflowService::V1::DescribeWorkflowExecutionRequest.encode(request)
      response = core_connection.call(:describe_workflow_execution, encoded, metadata, timeout)

      Temporalio::Api::WorkflowService::V1::DescribeWorkflowExecutionResponse.decode(response)
    end

    # @param request [Temporalio::Api::WorkflowService::V1::DescribeTaskQueueRequest]
    # @param metadata [Hash<String, String>] Headers used on the RPC call.
    #   Keys here override client-level RPC metadata keys.
    # @param timeout [Integer] Optional RPC deadline to set for each RPC call.
    #
    # @return [Temporalio::Api::WorkflowService::V1::DescribeTaskQueueResponse]
    def describe_task_queue(request, metadata: {}, timeout: nil)
      encoded = Temporalio::Api::WorkflowService::V1::DescribeTaskQueueRequest.encode(request)
      response = core_connection.call(:describe_task_queue, encoded, metadata, timeout)

      Temporalio::Api::WorkflowService::V1::DescribeTaskQueueResponse.decode(response)
    end

    # @param request [Temporalio::Api::WorkflowService::V1::GetClusterInfoRequest]
    # @param metadata [Hash<String, String>] Headers used on the RPC call.
    #   Keys here override client-level RPC metadata keys.
    # @param timeout [Integer] Optional RPC deadline to set for each RPC call.
    #
    # @return [Temporalio::Api::WorkflowService::V1::GetClusterInfoResponse]
    def get_cluster_info(request, metadata: {}, timeout: nil)
      encoded = Temporalio::Api::WorkflowService::V1::GetClusterInfoRequest.encode(request)
      response = core_connection.call(:get_cluster_info, encoded, metadata, timeout)

      Temporalio::Api::WorkflowService::V1::GetClusterInfoResponse.decode(response)
    end

    # @param request [Temporalio::Api::WorkflowService::V1::GetSystemInfoRequest]
    # @param metadata [Hash<String, String>] Headers used on the RPC call.
    #   Keys here override client-level RPC metadata keys.
    # @param timeout [Integer] Optional RPC deadline to set for each RPC call.
    #
    # @return [Temporalio::Api::WorkflowService::V1::GetSystemInfoResponse]
    def get_system_info(request, metadata: {}, timeout: nil)
      encoded = Temporalio::Api::WorkflowService::V1::GetSystemInfoRequest.encode(request)
      response = core_connection.call(:get_system_info, encoded, metadata, timeout)

      Temporalio::Api::WorkflowService::V1::GetSystemInfoResponse.decode(response)
    end

    # @param request [Temporalio::Api::WorkflowService::V1::ListTaskQueuePartitionsRequest]
    # @param metadata [Hash<String, String>] Headers used on the RPC call.
    #   Keys here override client-level RPC metadata keys.
    # @param timeout [Integer] Optional RPC deadline to set for each RPC call.
    #
    # @return [Temporalio::Api::WorkflowService::V1::ListTaskQueuePartitionsResponse]
    def list_task_queue_partitions(request, metadata: {}, timeout: nil)
      encoded = Temporalio::Api::WorkflowService::V1::ListTaskQueuePartitionsRequest.encode(request)
      response = core_connection.call(:list_task_queue_partitions, encoded, metadata, timeout)

      Temporalio::Api::WorkflowService::V1::ListTaskQueuePartitionsResponse.decode(response)
    end

    # @param request [Temporalio::Api::WorkflowService::V1::CreateScheduleRequest]
    # @param metadata [Hash<String, String>] Headers used on the RPC call.
    #   Keys here override client-level RPC metadata keys.
    # @param timeout [Integer] Optional RPC deadline to set for each RPC call.
    #
    # @return [Temporalio::Api::WorkflowService::V1::CreateScheduleResponse]
    def create_schedule(request, metadata: {}, timeout: nil)
      encoded = Temporalio::Api::WorkflowService::V1::CreateScheduleRequest.encode(request)
      response = core_connection.call(:create_schedule, encoded, metadata, timeout)

      Temporalio::Api::WorkflowService::V1::CreateScheduleResponse.decode(response)
    end

    # @param request [Temporalio::Api::WorkflowService::V1::DescribeScheduleRequest]
    # @param metadata [Hash<String, String>] Headers used on the RPC call.
    #   Keys here override client-level RPC metadata keys.
    # @param timeout [Integer] Optional RPC deadline to set for each RPC call.
    #
    # @return [Temporalio::Api::WorkflowService::V1::DescribeScheduleResponse]
    def describe_schedule(request, metadata: {}, timeout: nil)
      encoded = Temporalio::Api::WorkflowService::V1::DescribeScheduleRequest.encode(request)
      response = core_connection.call(:describe_schedule, encoded, metadata, timeout)

      Temporalio::Api::WorkflowService::V1::DescribeScheduleResponse.decode(response)
    end

    # @param request [Temporalio::Api::WorkflowService::V1::UpdateScheduleRequest]
    # @param metadata [Hash<String, String>] Headers used on the RPC call.
    #   Keys here override client-level RPC metadata keys.
    # @param timeout [Integer] Optional RPC deadline to set for each RPC call.
    #
    # @return [Temporalio::Api::WorkflowService::V1::UpdateScheduleResponse]
    def update_schedule(request, metadata: {}, timeout: nil)
      encoded = Temporalio::Api::WorkflowService::V1::UpdateScheduleRequest.encode(request)
      response = core_connection.call(:update_schedule, encoded, metadata, timeout)

      Temporalio::Api::WorkflowService::V1::UpdateScheduleResponse.decode(response)
    end

    # @param request [Temporalio::Api::WorkflowService::V1::PatchScheduleRequest]
    # @param metadata [Hash<String, String>] Headers used on the RPC call.
    #   Keys here override client-level RPC metadata keys.
    # @param timeout [Integer] Optional RPC deadline to set for each RPC call.
    #
    # @return [Temporalio::Api::WorkflowService::V1::PatchScheduleResponse]
    def patch_schedule(request, metadata: {}, timeout: nil)
      encoded = Temporalio::Api::WorkflowService::V1::PatchScheduleRequest.encode(request)
      response = core_connection.call(:patch_schedule, encoded, metadata, timeout)

      Temporalio::Api::WorkflowService::V1::PatchScheduleResponse.decode(response)
    end

    # @param request [Temporalio::Api::WorkflowService::V1::ListScheduleMatchingTimesRequest]
    # @param metadata [Hash<String, String>] Headers used on the RPC call.
    #   Keys here override client-level RPC metadata keys.
    # @param timeout [Integer] Optional RPC deadline to set for each RPC call.
    #
    # @return [Temporalio::Api::WorkflowService::V1::ListScheduleMatchingTimesResponse]
    def list_schedule_matching_times(request, metadata: {}, timeout: nil)
      encoded = Temporalio::Api::WorkflowService::V1::ListScheduleMatchingTimesRequest.encode(request)
      response = core_connection.call(:list_schedule_matching_times, encoded, metadata, timeout)

      Temporalio::Api::WorkflowService::V1::ListScheduleMatchingTimesResponse.decode(response)
    end

    # @param request [Temporalio::Api::WorkflowService::V1::DeleteScheduleRequest]
    # @param metadata [Hash<String, String>] Headers used on the RPC call.
    #   Keys here override client-level RPC metadata keys.
    # @param timeout [Integer] Optional RPC deadline to set for each RPC call.
    #
    # @return [Temporalio::Api::WorkflowService::V1::DeleteScheduleResponse]
    def delete_schedule(request, metadata: {}, timeout: nil)
      encoded = Temporalio::Api::WorkflowService::V1::DeleteScheduleRequest.encode(request)
      response = core_connection.call(:delete_schedule, encoded, metadata, timeout)

      Temporalio::Api::WorkflowService::V1::DeleteScheduleResponse.decode(response)
    end

    # @param request [Temporalio::Api::WorkflowService::V1::ListSchedulesRequest]
    # @param metadata [Hash<String, String>] Headers used on the RPC call.
    #   Keys here override client-level RPC metadata keys.
    # @param timeout [Integer] Optional RPC deadline to set for each RPC call.
    #
    # @return [Temporalio::Api::WorkflowService::V1::ListSchedulesResponse]
    def list_schedules(request, metadata: {}, timeout: nil)
      encoded = Temporalio::Api::WorkflowService::V1::ListSchedulesRequest.encode(request)
      response = core_connection.call(:list_schedules, encoded, metadata, timeout)

      Temporalio::Api::WorkflowService::V1::ListSchedulesResponse.decode(response)
    end

    # @param request [Temporalio::Api::WorkflowService::V1::UpdateWorkerBuildIdOrderingRequest]
    # @param metadata [Hash<String, String>] Headers used on the RPC call.
    #   Keys here override client-level RPC metadata keys.
    # @param timeout [Integer] Optional RPC deadline to set for each RPC call.
    #
    # @return [Temporalio::Api::WorkflowService::V1::UpdateWorkerBuildIdOrderingResponse]
    def update_worker_build_id_ordering(request, metadata: {}, timeout: nil)
      encoded = Temporalio::Api::WorkflowService::V1::UpdateWorkerBuildIdOrderingRequest.encode(request)
      response = core_connection.call(:update_worker_build_id_ordering, encoded, metadata, timeout)

      Temporalio::Api::WorkflowService::V1::UpdateWorkerBuildIdOrderingResponse.decode(response)
    end

    # @param request [Temporalio::Api::WorkflowService::V1::GetWorkerBuildIdOrderingRequest]
    # @param metadata [Hash<String, String>] Headers used on the RPC call.
    #   Keys here override client-level RPC metadata keys.
    # @param timeout [Integer] Optional RPC deadline to set for each RPC call.
    #
    # @return [Temporalio::Api::WorkflowService::V1::GetWorkerBuildIdOrderingResponse]
    def get_worker_build_id_ordering(request, metadata: {}, timeout: nil)
      encoded = Temporalio::Api::WorkflowService::V1::GetWorkerBuildIdOrderingRequest.encode(request)
      response = core_connection.call(:get_worker_build_id_ordering, encoded, metadata, timeout)

      Temporalio::Api::WorkflowService::V1::GetWorkerBuildIdOrderingResponse.decode(response)
    end

    # @param request [Temporalio::Api::WorkflowService::V1::UpdateWorkflowRequest]
    # @param metadata [Hash<String, String>] Headers used on the RPC call.
    #   Keys here override client-level RPC metadata keys.
    # @param timeout [Integer] Optional RPC deadline to set for each RPC call.
    #
    # @return [Temporalio::Api::WorkflowService::V1::UpdateWorkflowResponse]
    def update_workflow(request, metadata: {}, timeout: nil)
      encoded = Temporalio::Api::WorkflowService::V1::UpdateWorkflowRequest.encode(request)
      response = core_connection.call(:update_workflow, encoded, metadata, timeout)

      Temporalio::Api::WorkflowService::V1::UpdateWorkflowResponse.decode(response)
    end

    # @param request [Temporalio::Api::WorkflowService::V1::StartBatchOperationRequest]
    # @param metadata [Hash<String, String>] Headers used on the RPC call.
    #   Keys here override client-level RPC metadata keys.
    # @param timeout [Integer] Optional RPC deadline to set for each RPC call.
    #
    # @return [Temporalio::Api::WorkflowService::V1::StartBatchOperationResponse]
    def start_batch_operation(request, metadata: {}, timeout: nil)
      encoded = Temporalio::Api::WorkflowService::V1::StartBatchOperationRequest.encode(request)
      response = core_connection.call(:start_batch_operation, encoded, metadata, timeout)

      Temporalio::Api::WorkflowService::V1::StartBatchOperationResponse.decode(response)
    end

    # @param request [Temporalio::Api::WorkflowService::V1::StopBatchOperationRequest]
    # @param metadata [Hash<String, String>] Headers used on the RPC call.
    #   Keys here override client-level RPC metadata keys.
    # @param timeout [Integer] Optional RPC deadline to set for each RPC call.
    #
    # @return [Temporalio::Api::WorkflowService::V1::StopBatchOperationResponse]
    def stop_batch_operation(request, metadata: {}, timeout: nil)
      encoded = Temporalio::Api::WorkflowService::V1::StopBatchOperationRequest.encode(request)
      response = core_connection.call(:stop_batch_operation, encoded, metadata, timeout)

      Temporalio::Api::WorkflowService::V1::StopBatchOperationResponse.decode(response)
    end

    # @param request [Temporalio::Api::WorkflowService::V1::DescribeBatchOperationRequest]
    # @param metadata [Hash<String, String>] Headers used on the RPC call.
    #   Keys here override client-level RPC metadata keys.
    # @param timeout [Integer] Optional RPC deadline to set for each RPC call.
    #
    # @return [Temporalio::Api::WorkflowService::V1::DescribeBatchOperationResponse]
    def describe_batch_operation(request, metadata: {}, timeout: nil)
      encoded = Temporalio::Api::WorkflowService::V1::DescribeBatchOperationRequest.encode(request)
      response = core_connection.call(:describe_batch_operation, encoded, metadata, timeout)

      Temporalio::Api::WorkflowService::V1::DescribeBatchOperationResponse.decode(response)
    end

    # @param request [Temporalio::Api::WorkflowService::V1::ListBatchOperationsRequest]
    # @param metadata [Hash<String, String>] Headers used on the RPC call.
    #   Keys here override client-level RPC metadata keys.
    # @param timeout [Integer] Optional RPC deadline to set for each RPC call.
    #
    # @return [Temporalio::Api::WorkflowService::V1::ListBatchOperationsResponse]
    def list_batch_operations(request, metadata: {}, timeout: nil)
      encoded = Temporalio::Api::WorkflowService::V1::ListBatchOperationsRequest.encode(request)
      response = core_connection.call(:list_batch_operations, encoded, metadata, timeout)

      Temporalio::Api::WorkflowService::V1::ListBatchOperationsResponse.decode(response)
    end

    private

    def parse_url(url)
      # Turn this into a valid URI before parsing
      uri = URI.parse(url.include?('://') ? url : "//#{url}")
      raise Temporalio::Error, 'Target host as URL with scheme are not supported' if uri.scheme

      # TODO: Add support for mTLS
      uri.scheme = 'http'
      uri.to_s
    end
  end
end
