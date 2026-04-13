# typed: false
# frozen_string_literal: true

# Generated code.  DO NOT EDIT!

class Temporalio::Client::Connection::WorkflowService < ::Temporalio::Client::Connection::Service
  extend T::Sig

  sig { params(connection: Temporalio::Client::Connection).void }
  def initialize(connection); end

  sig { params(request: Temporalio::Api::WorkflowService::V1::RegisterNamespaceRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::WorkflowService::V1::RegisterNamespaceResponse) }
  def register_namespace(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::WorkflowService::V1::DescribeNamespaceRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::WorkflowService::V1::DescribeNamespaceResponse) }
  def describe_namespace(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::WorkflowService::V1::ListNamespacesRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::WorkflowService::V1::ListNamespacesResponse) }
  def list_namespaces(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::WorkflowService::V1::UpdateNamespaceRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::WorkflowService::V1::UpdateNamespaceResponse) }
  def update_namespace(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::WorkflowService::V1::DeprecateNamespaceRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::WorkflowService::V1::DeprecateNamespaceResponse) }
  def deprecate_namespace(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::WorkflowService::V1::StartWorkflowExecutionRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::WorkflowService::V1::StartWorkflowExecutionResponse) }
  def start_workflow_execution(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::WorkflowService::V1::ExecuteMultiOperationRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::WorkflowService::V1::ExecuteMultiOperationResponse) }
  def execute_multi_operation(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::WorkflowService::V1::GetWorkflowExecutionHistoryRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::WorkflowService::V1::GetWorkflowExecutionHistoryResponse) }
  def get_workflow_execution_history(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::WorkflowService::V1::GetWorkflowExecutionHistoryReverseRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::WorkflowService::V1::GetWorkflowExecutionHistoryReverseResponse) }
  def get_workflow_execution_history_reverse(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::WorkflowService::V1::PollWorkflowTaskQueueRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::WorkflowService::V1::PollWorkflowTaskQueueResponse) }
  def poll_workflow_task_queue(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::WorkflowService::V1::RespondWorkflowTaskCompletedRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::WorkflowService::V1::RespondWorkflowTaskCompletedResponse) }
  def respond_workflow_task_completed(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::WorkflowService::V1::RespondWorkflowTaskFailedRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::WorkflowService::V1::RespondWorkflowTaskFailedResponse) }
  def respond_workflow_task_failed(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::WorkflowService::V1::PollActivityTaskQueueRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::WorkflowService::V1::PollActivityTaskQueueResponse) }
  def poll_activity_task_queue(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::WorkflowService::V1::RecordActivityTaskHeartbeatRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::WorkflowService::V1::RecordActivityTaskHeartbeatResponse) }
  def record_activity_task_heartbeat(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::WorkflowService::V1::RecordActivityTaskHeartbeatByIdRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::WorkflowService::V1::RecordActivityTaskHeartbeatByIdResponse) }
  def record_activity_task_heartbeat_by_id(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::WorkflowService::V1::RespondActivityTaskCompletedRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::WorkflowService::V1::RespondActivityTaskCompletedResponse) }
  def respond_activity_task_completed(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::WorkflowService::V1::RespondActivityTaskCompletedByIdRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::WorkflowService::V1::RespondActivityTaskCompletedByIdResponse) }
  def respond_activity_task_completed_by_id(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::WorkflowService::V1::RespondActivityTaskFailedRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::WorkflowService::V1::RespondActivityTaskFailedResponse) }
  def respond_activity_task_failed(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::WorkflowService::V1::RespondActivityTaskFailedByIdRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::WorkflowService::V1::RespondActivityTaskFailedByIdResponse) }
  def respond_activity_task_failed_by_id(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::WorkflowService::V1::RespondActivityTaskCanceledRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::WorkflowService::V1::RespondActivityTaskCanceledResponse) }
  def respond_activity_task_canceled(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::WorkflowService::V1::RespondActivityTaskCanceledByIdRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::WorkflowService::V1::RespondActivityTaskCanceledByIdResponse) }
  def respond_activity_task_canceled_by_id(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::WorkflowService::V1::RequestCancelWorkflowExecutionRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::WorkflowService::V1::RequestCancelWorkflowExecutionResponse) }
  def request_cancel_workflow_execution(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::WorkflowService::V1::SignalWorkflowExecutionRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::WorkflowService::V1::SignalWorkflowExecutionResponse) }
  def signal_workflow_execution(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::WorkflowService::V1::SignalWithStartWorkflowExecutionRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::WorkflowService::V1::SignalWithStartWorkflowExecutionResponse) }
  def signal_with_start_workflow_execution(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::WorkflowService::V1::ResetWorkflowExecutionRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::WorkflowService::V1::ResetWorkflowExecutionResponse) }
  def reset_workflow_execution(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::WorkflowService::V1::TerminateWorkflowExecutionRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::WorkflowService::V1::TerminateWorkflowExecutionResponse) }
  def terminate_workflow_execution(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::WorkflowService::V1::DeleteWorkflowExecutionRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::WorkflowService::V1::DeleteWorkflowExecutionResponse) }
  def delete_workflow_execution(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::WorkflowService::V1::ListOpenWorkflowExecutionsRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::WorkflowService::V1::ListOpenWorkflowExecutionsResponse) }
  def list_open_workflow_executions(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::WorkflowService::V1::ListClosedWorkflowExecutionsRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::WorkflowService::V1::ListClosedWorkflowExecutionsResponse) }
  def list_closed_workflow_executions(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::WorkflowService::V1::ListWorkflowExecutionsRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::WorkflowService::V1::ListWorkflowExecutionsResponse) }
  def list_workflow_executions(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::WorkflowService::V1::ListArchivedWorkflowExecutionsRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::WorkflowService::V1::ListArchivedWorkflowExecutionsResponse) }
  def list_archived_workflow_executions(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::WorkflowService::V1::ScanWorkflowExecutionsRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::WorkflowService::V1::ScanWorkflowExecutionsResponse) }
  def scan_workflow_executions(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::WorkflowService::V1::CountWorkflowExecutionsRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::WorkflowService::V1::CountWorkflowExecutionsResponse) }
  def count_workflow_executions(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::WorkflowService::V1::GetSearchAttributesRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::WorkflowService::V1::GetSearchAttributesResponse) }
  def get_search_attributes(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::WorkflowService::V1::RespondQueryTaskCompletedRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::WorkflowService::V1::RespondQueryTaskCompletedResponse) }
  def respond_query_task_completed(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::WorkflowService::V1::ResetStickyTaskQueueRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::WorkflowService::V1::ResetStickyTaskQueueResponse) }
  def reset_sticky_task_queue(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::WorkflowService::V1::ShutdownWorkerRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::WorkflowService::V1::ShutdownWorkerResponse) }
  def shutdown_worker(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::WorkflowService::V1::QueryWorkflowRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::WorkflowService::V1::QueryWorkflowResponse) }
  def query_workflow(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::WorkflowService::V1::DescribeWorkflowExecutionRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::WorkflowService::V1::DescribeWorkflowExecutionResponse) }
  def describe_workflow_execution(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::WorkflowService::V1::DescribeTaskQueueRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::WorkflowService::V1::DescribeTaskQueueResponse) }
  def describe_task_queue(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::WorkflowService::V1::GetClusterInfoRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::WorkflowService::V1::GetClusterInfoResponse) }
  def get_cluster_info(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::WorkflowService::V1::GetSystemInfoRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::WorkflowService::V1::GetSystemInfoResponse) }
  def get_system_info(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::WorkflowService::V1::ListTaskQueuePartitionsRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::WorkflowService::V1::ListTaskQueuePartitionsResponse) }
  def list_task_queue_partitions(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::WorkflowService::V1::CreateScheduleRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::WorkflowService::V1::CreateScheduleResponse) }
  def create_schedule(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::WorkflowService::V1::DescribeScheduleRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::WorkflowService::V1::DescribeScheduleResponse) }
  def describe_schedule(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::WorkflowService::V1::UpdateScheduleRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::WorkflowService::V1::UpdateScheduleResponse) }
  def update_schedule(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::WorkflowService::V1::PatchScheduleRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::WorkflowService::V1::PatchScheduleResponse) }
  def patch_schedule(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::WorkflowService::V1::ListScheduleMatchingTimesRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::WorkflowService::V1::ListScheduleMatchingTimesResponse) }
  def list_schedule_matching_times(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::WorkflowService::V1::DeleteScheduleRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::WorkflowService::V1::DeleteScheduleResponse) }
  def delete_schedule(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::WorkflowService::V1::ListSchedulesRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::WorkflowService::V1::ListSchedulesResponse) }
  def list_schedules(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::WorkflowService::V1::CountSchedulesRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::WorkflowService::V1::CountSchedulesResponse) }
  def count_schedules(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::WorkflowService::V1::UpdateWorkerBuildIdCompatibilityRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::WorkflowService::V1::UpdateWorkerBuildIdCompatibilityResponse) }
  def update_worker_build_id_compatibility(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::WorkflowService::V1::GetWorkerBuildIdCompatibilityRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::WorkflowService::V1::GetWorkerBuildIdCompatibilityResponse) }
  def get_worker_build_id_compatibility(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::WorkflowService::V1::UpdateWorkerVersioningRulesRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::WorkflowService::V1::UpdateWorkerVersioningRulesResponse) }
  def update_worker_versioning_rules(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::WorkflowService::V1::GetWorkerVersioningRulesRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::WorkflowService::V1::GetWorkerVersioningRulesResponse) }
  def get_worker_versioning_rules(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::WorkflowService::V1::GetWorkerTaskReachabilityRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::WorkflowService::V1::GetWorkerTaskReachabilityResponse) }
  def get_worker_task_reachability(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::WorkflowService::V1::DescribeDeploymentRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::WorkflowService::V1::DescribeDeploymentResponse) }
  def describe_deployment(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::WorkflowService::V1::DescribeWorkerDeploymentVersionRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::WorkflowService::V1::DescribeWorkerDeploymentVersionResponse) }
  def describe_worker_deployment_version(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::WorkflowService::V1::ListDeploymentsRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::WorkflowService::V1::ListDeploymentsResponse) }
  def list_deployments(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::WorkflowService::V1::GetDeploymentReachabilityRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::WorkflowService::V1::GetDeploymentReachabilityResponse) }
  def get_deployment_reachability(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::WorkflowService::V1::GetCurrentDeploymentRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::WorkflowService::V1::GetCurrentDeploymentResponse) }
  def get_current_deployment(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::WorkflowService::V1::SetCurrentDeploymentRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::WorkflowService::V1::SetCurrentDeploymentResponse) }
  def set_current_deployment(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::WorkflowService::V1::SetWorkerDeploymentCurrentVersionRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::WorkflowService::V1::SetWorkerDeploymentCurrentVersionResponse) }
  def set_worker_deployment_current_version(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::WorkflowService::V1::DescribeWorkerDeploymentRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::WorkflowService::V1::DescribeWorkerDeploymentResponse) }
  def describe_worker_deployment(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::WorkflowService::V1::DeleteWorkerDeploymentRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::WorkflowService::V1::DeleteWorkerDeploymentResponse) }
  def delete_worker_deployment(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::WorkflowService::V1::DeleteWorkerDeploymentVersionRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::WorkflowService::V1::DeleteWorkerDeploymentVersionResponse) }
  def delete_worker_deployment_version(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::WorkflowService::V1::SetWorkerDeploymentRampingVersionRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::WorkflowService::V1::SetWorkerDeploymentRampingVersionResponse) }
  def set_worker_deployment_ramping_version(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::WorkflowService::V1::ListWorkerDeploymentsRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::WorkflowService::V1::ListWorkerDeploymentsResponse) }
  def list_worker_deployments(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::WorkflowService::V1::UpdateWorkerDeploymentVersionMetadataRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::WorkflowService::V1::UpdateWorkerDeploymentVersionMetadataResponse) }
  def update_worker_deployment_version_metadata(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::WorkflowService::V1::SetWorkerDeploymentManagerRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::WorkflowService::V1::SetWorkerDeploymentManagerResponse) }
  def set_worker_deployment_manager(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::WorkflowService::V1::UpdateWorkflowExecutionRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::WorkflowService::V1::UpdateWorkflowExecutionResponse) }
  def update_workflow_execution(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::WorkflowService::V1::PollWorkflowExecutionUpdateRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::WorkflowService::V1::PollWorkflowExecutionUpdateResponse) }
  def poll_workflow_execution_update(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::WorkflowService::V1::StartBatchOperationRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::WorkflowService::V1::StartBatchOperationResponse) }
  def start_batch_operation(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::WorkflowService::V1::StopBatchOperationRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::WorkflowService::V1::StopBatchOperationResponse) }
  def stop_batch_operation(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::WorkflowService::V1::DescribeBatchOperationRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::WorkflowService::V1::DescribeBatchOperationResponse) }
  def describe_batch_operation(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::WorkflowService::V1::ListBatchOperationsRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::WorkflowService::V1::ListBatchOperationsResponse) }
  def list_batch_operations(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::WorkflowService::V1::PollNexusTaskQueueRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::WorkflowService::V1::PollNexusTaskQueueResponse) }
  def poll_nexus_task_queue(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::WorkflowService::V1::RespondNexusTaskCompletedRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::WorkflowService::V1::RespondNexusTaskCompletedResponse) }
  def respond_nexus_task_completed(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::WorkflowService::V1::RespondNexusTaskFailedRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::WorkflowService::V1::RespondNexusTaskFailedResponse) }
  def respond_nexus_task_failed(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::WorkflowService::V1::UpdateActivityOptionsRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::WorkflowService::V1::UpdateActivityOptionsResponse) }
  def update_activity_options(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::WorkflowService::V1::UpdateWorkflowExecutionOptionsRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::WorkflowService::V1::UpdateWorkflowExecutionOptionsResponse) }
  def update_workflow_execution_options(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::WorkflowService::V1::PauseActivityRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::WorkflowService::V1::PauseActivityResponse) }
  def pause_activity(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::WorkflowService::V1::UnpauseActivityRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::WorkflowService::V1::UnpauseActivityResponse) }
  def unpause_activity(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::WorkflowService::V1::ResetActivityRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::WorkflowService::V1::ResetActivityResponse) }
  def reset_activity(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::WorkflowService::V1::CreateWorkflowRuleRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::WorkflowService::V1::CreateWorkflowRuleResponse) }
  def create_workflow_rule(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::WorkflowService::V1::DescribeWorkflowRuleRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::WorkflowService::V1::DescribeWorkflowRuleResponse) }
  def describe_workflow_rule(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::WorkflowService::V1::DeleteWorkflowRuleRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::WorkflowService::V1::DeleteWorkflowRuleResponse) }
  def delete_workflow_rule(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::WorkflowService::V1::ListWorkflowRulesRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::WorkflowService::V1::ListWorkflowRulesResponse) }
  def list_workflow_rules(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::WorkflowService::V1::TriggerWorkflowRuleRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::WorkflowService::V1::TriggerWorkflowRuleResponse) }
  def trigger_workflow_rule(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::WorkflowService::V1::RecordWorkerHeartbeatRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::WorkflowService::V1::RecordWorkerHeartbeatResponse) }
  def record_worker_heartbeat(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::WorkflowService::V1::ListWorkersRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::WorkflowService::V1::ListWorkersResponse) }
  def list_workers(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::WorkflowService::V1::UpdateTaskQueueConfigRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::WorkflowService::V1::UpdateTaskQueueConfigResponse) }
  def update_task_queue_config(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::WorkflowService::V1::FetchWorkerConfigRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::WorkflowService::V1::FetchWorkerConfigResponse) }
  def fetch_worker_config(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::WorkflowService::V1::UpdateWorkerConfigRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::WorkflowService::V1::UpdateWorkerConfigResponse) }
  def update_worker_config(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::WorkflowService::V1::DescribeWorkerRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::WorkflowService::V1::DescribeWorkerResponse) }
  def describe_worker(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::WorkflowService::V1::PauseWorkflowExecutionRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::WorkflowService::V1::PauseWorkflowExecutionResponse) }
  def pause_workflow_execution(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::WorkflowService::V1::UnpauseWorkflowExecutionRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::WorkflowService::V1::UnpauseWorkflowExecutionResponse) }
  def unpause_workflow_execution(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::WorkflowService::V1::StartActivityExecutionRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::WorkflowService::V1::StartActivityExecutionResponse) }
  def start_activity_execution(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::WorkflowService::V1::DescribeActivityExecutionRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::WorkflowService::V1::DescribeActivityExecutionResponse) }
  def describe_activity_execution(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::WorkflowService::V1::PollActivityExecutionRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::WorkflowService::V1::PollActivityExecutionResponse) }
  def poll_activity_execution(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::WorkflowService::V1::ListActivityExecutionsRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::WorkflowService::V1::ListActivityExecutionsResponse) }
  def list_activity_executions(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::WorkflowService::V1::CountActivityExecutionsRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::WorkflowService::V1::CountActivityExecutionsResponse) }
  def count_activity_executions(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::WorkflowService::V1::RequestCancelActivityExecutionRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::WorkflowService::V1::RequestCancelActivityExecutionResponse) }
  def request_cancel_activity_execution(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::WorkflowService::V1::TerminateActivityExecutionRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::WorkflowService::V1::TerminateActivityExecutionResponse) }
  def terminate_activity_execution(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::WorkflowService::V1::DeleteActivityExecutionRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::WorkflowService::V1::DeleteActivityExecutionResponse) }
  def delete_activity_execution(request, rpc_options: T.unsafe(nil)); end
end
