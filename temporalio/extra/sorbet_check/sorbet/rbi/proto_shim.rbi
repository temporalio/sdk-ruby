# typed: false
# frozen_string_literal: true

# Minimal shim for proto classes referenced in the SDK RBI.
# Generated — do not edit by hand. Regenerate after updating proto references.

module Google
  module Protobuf
    class Empty; end
  end
end
module Temporalio
  module Api
    module Cloud
      module CloudService
        module V1
          class AddNamespaceRegionRequest; end
          class AddNamespaceRegionResponse; end
          class AddUserGroupMemberRequest; end
          class AddUserGroupMemberResponse; end
          class CreateApiKeyRequest; end
          class CreateApiKeyResponse; end
          class CreateConnectivityRuleRequest; end
          class CreateConnectivityRuleResponse; end
          class CreateNamespaceExportSinkRequest; end
          class CreateNamespaceExportSinkResponse; end
          class CreateNamespaceRequest; end
          class CreateNamespaceResponse; end
          class CreateNexusEndpointRequest; end
          class CreateNexusEndpointResponse; end
          class CreateServiceAccountRequest; end
          class CreateServiceAccountResponse; end
          class CreateUserGroupRequest; end
          class CreateUserGroupResponse; end
          class CreateUserRequest; end
          class CreateUserResponse; end
          class DeleteApiKeyRequest; end
          class DeleteApiKeyResponse; end
          class DeleteConnectivityRuleRequest; end
          class DeleteConnectivityRuleResponse; end
          class DeleteNamespaceExportSinkRequest; end
          class DeleteNamespaceExportSinkResponse; end
          class DeleteNamespaceRegionRequest; end
          class DeleteNamespaceRegionResponse; end
          class DeleteNamespaceRequest; end
          class DeleteNamespaceResponse; end
          class DeleteNexusEndpointRequest; end
          class DeleteNexusEndpointResponse; end
          class DeleteServiceAccountRequest; end
          class DeleteServiceAccountResponse; end
          class DeleteUserGroupRequest; end
          class DeleteUserGroupResponse; end
          class DeleteUserRequest; end
          class DeleteUserResponse; end
          class FailoverNamespaceRegionRequest; end
          class FailoverNamespaceRegionResponse; end
          class GetAccountRequest; end
          class GetAccountResponse; end
          class GetApiKeyRequest; end
          class GetApiKeyResponse; end
          class GetApiKeysRequest; end
          class GetApiKeysResponse; end
          class GetAsyncOperationRequest; end
          class GetAsyncOperationResponse; end
          class GetConnectivityRuleRequest; end
          class GetConnectivityRuleResponse; end
          class GetConnectivityRulesRequest; end
          class GetConnectivityRulesResponse; end
          class GetNamespaceExportSinkRequest; end
          class GetNamespaceExportSinkResponse; end
          class GetNamespaceExportSinksRequest; end
          class GetNamespaceExportSinksResponse; end
          class GetNamespaceRequest; end
          class GetNamespaceResponse; end
          class GetNamespacesRequest; end
          class GetNamespacesResponse; end
          class GetNexusEndpointRequest; end
          class GetNexusEndpointResponse; end
          class GetNexusEndpointsRequest; end
          class GetNexusEndpointsResponse; end
          class GetRegionRequest; end
          class GetRegionResponse; end
          class GetRegionsRequest; end
          class GetRegionsResponse; end
          class GetServiceAccountRequest; end
          class GetServiceAccountResponse; end
          class GetServiceAccountsRequest; end
          class GetServiceAccountsResponse; end
          class GetUsageRequest; end
          class GetUsageResponse; end
          class GetUserGroupMembersRequest; end
          class GetUserGroupMembersResponse; end
          class GetUserGroupRequest; end
          class GetUserGroupResponse; end
          class GetUserGroupsRequest; end
          class GetUserGroupsResponse; end
          class GetUserRequest; end
          class GetUserResponse; end
          class GetUsersRequest; end
          class GetUsersResponse; end
          class RemoveUserGroupMemberRequest; end
          class RemoveUserGroupMemberResponse; end
          class RenameCustomSearchAttributeRequest; end
          class RenameCustomSearchAttributeResponse; end
          class SetServiceAccountNamespaceAccessRequest; end
          class SetServiceAccountNamespaceAccessResponse; end
          class SetUserGroupNamespaceAccessRequest; end
          class SetUserGroupNamespaceAccessResponse; end
          class SetUserNamespaceAccessRequest; end
          class SetUserNamespaceAccessResponse; end
          class UpdateAccountRequest; end
          class UpdateAccountResponse; end
          class UpdateApiKeyRequest; end
          class UpdateApiKeyResponse; end
          class UpdateNamespaceExportSinkRequest; end
          class UpdateNamespaceExportSinkResponse; end
          class UpdateNamespaceRequest; end
          class UpdateNamespaceResponse; end
          class UpdateNamespaceTagsRequest; end
          class UpdateNamespaceTagsResponse; end
          class UpdateNexusEndpointRequest; end
          class UpdateNexusEndpointResponse; end
          class UpdateServiceAccountRequest; end
          class UpdateServiceAccountResponse; end
          class UpdateUserGroupRequest; end
          class UpdateUserGroupResponse; end
          class UpdateUserRequest; end
          class UpdateUserResponse; end
          class ValidateAccountAuditLogSinkRequest; end
          class ValidateAccountAuditLogSinkResponse; end
          class ValidateNamespaceExportSinkRequest; end
          class ValidateNamespaceExportSinkResponse; end
        end
      end
    end
    module Common
      module V1
        class GrpcStatus; end
        class Payload; end
        class Payloads; end
        class WorkflowExecution; end
      end
    end
    module Failure
      module V1
        class Failure; end
      end
    end
    module History
      module V1
        class HistoryEvent; end
      end
    end
    module OperatorService
      module V1
        class AddOrUpdateRemoteClusterRequest; end
        class AddOrUpdateRemoteClusterResponse; end
        class AddSearchAttributesRequest; end
        class AddSearchAttributesResponse; end
        class CreateNexusEndpointRequest; end
        class CreateNexusEndpointResponse; end
        class DeleteNamespaceRequest; end
        class DeleteNamespaceResponse; end
        class DeleteNexusEndpointRequest; end
        class DeleteNexusEndpointResponse; end
        class GetNexusEndpointRequest; end
        class GetNexusEndpointResponse; end
        class ListClustersRequest; end
        class ListClustersResponse; end
        class ListNexusEndpointsRequest; end
        class ListNexusEndpointsResponse; end
        class ListSearchAttributesRequest; end
        class ListSearchAttributesResponse; end
        class RemoveRemoteClusterRequest; end
        class RemoveRemoteClusterResponse; end
        class RemoveSearchAttributesRequest; end
        class RemoveSearchAttributesResponse; end
        class UpdateNexusEndpointRequest; end
        class UpdateNexusEndpointResponse; end
      end
    end
    module Schedule
      module V1
        class ScheduleActionResult; end
        class ScheduleInfo; end
        class ScheduleListEntry; end
        class ScheduleListInfo; end
      end
    end
    module TestService
      module V1
        class GetCurrentTimeResponse; end
        class LockTimeSkippingRequest; end
        class LockTimeSkippingResponse; end
        class SleepRequest; end
        class SleepResponse; end
        class SleepUntilRequest; end
        class UnlockTimeSkippingRequest; end
        class UnlockTimeSkippingResponse; end
      end
    end
    module Update
      module V1
        class Outcome; end
      end
    end
    module Workflow
      module V1
        class WorkflowExecutionInfo; end
      end
    end
    module WorkflowService
      module V1
        class CountActivityExecutionsRequest; end
        class CountActivityExecutionsResponse; end
        class CountSchedulesRequest; end
        class CountSchedulesResponse; end
        class CountWorkflowExecutionsRequest; end
        class CountWorkflowExecutionsResponse; end
        class CreateScheduleRequest; end
        class CreateScheduleResponse; end
        class CreateWorkflowRuleRequest; end
        class CreateWorkflowRuleResponse; end
        class DeleteActivityExecutionRequest; end
        class DeleteActivityExecutionResponse; end
        class DeleteScheduleRequest; end
        class DeleteScheduleResponse; end
        class DeleteWorkerDeploymentRequest; end
        class DeleteWorkerDeploymentResponse; end
        class DeleteWorkerDeploymentVersionRequest; end
        class DeleteWorkerDeploymentVersionResponse; end
        class DeleteWorkflowExecutionRequest; end
        class DeleteWorkflowExecutionResponse; end
        class DeleteWorkflowRuleRequest; end
        class DeleteWorkflowRuleResponse; end
        class DeprecateNamespaceRequest; end
        class DeprecateNamespaceResponse; end
        class DescribeActivityExecutionRequest; end
        class DescribeActivityExecutionResponse; end
        class DescribeBatchOperationRequest; end
        class DescribeBatchOperationResponse; end
        class DescribeDeploymentRequest; end
        class DescribeDeploymentResponse; end
        class DescribeNamespaceRequest; end
        class DescribeNamespaceResponse; end
        class DescribeScheduleRequest; end
        class DescribeScheduleResponse; end
        class DescribeTaskQueueRequest; end
        class DescribeTaskQueueResponse; end
        class DescribeWorkerDeploymentRequest; end
        class DescribeWorkerDeploymentResponse; end
        class DescribeWorkerDeploymentVersionRequest; end
        class DescribeWorkerDeploymentVersionResponse; end
        class DescribeWorkerRequest; end
        class DescribeWorkerResponse; end
        class DescribeWorkflowExecutionRequest; end
        class DescribeWorkflowExecutionResponse; end
        class DescribeWorkflowRuleRequest; end
        class DescribeWorkflowRuleResponse; end
        class ExecuteMultiOperationRequest; end
        class ExecuteMultiOperationResponse; end
        class FetchWorkerConfigRequest; end
        class FetchWorkerConfigResponse; end
        class GetClusterInfoRequest; end
        class GetClusterInfoResponse; end
        class GetCurrentDeploymentRequest; end
        class GetCurrentDeploymentResponse; end
        class GetDeploymentReachabilityRequest; end
        class GetDeploymentReachabilityResponse; end
        class GetSearchAttributesRequest; end
        class GetSearchAttributesResponse; end
        class GetSystemInfoRequest; end
        class GetSystemInfoResponse; end
        class GetWorkerBuildIdCompatibilityRequest; end
        class GetWorkerBuildIdCompatibilityResponse; end
        class GetWorkerTaskReachabilityRequest; end
        class GetWorkerTaskReachabilityResponse; end
        class GetWorkerVersioningRulesRequest; end
        class GetWorkerVersioningRulesResponse; end
        class GetWorkflowExecutionHistoryRequest; end
        class GetWorkflowExecutionHistoryResponse; end
        class GetWorkflowExecutionHistoryReverseRequest; end
        class GetWorkflowExecutionHistoryReverseResponse; end
        class ListActivityExecutionsRequest; end
        class ListActivityExecutionsResponse; end
        class ListArchivedWorkflowExecutionsRequest; end
        class ListArchivedWorkflowExecutionsResponse; end
        class ListBatchOperationsRequest; end
        class ListBatchOperationsResponse; end
        class ListClosedWorkflowExecutionsRequest; end
        class ListClosedWorkflowExecutionsResponse; end
        class ListDeploymentsRequest; end
        class ListDeploymentsResponse; end
        class ListNamespacesRequest; end
        class ListNamespacesResponse; end
        class ListOpenWorkflowExecutionsRequest; end
        class ListOpenWorkflowExecutionsResponse; end
        class ListScheduleMatchingTimesRequest; end
        class ListScheduleMatchingTimesResponse; end
        class ListSchedulesRequest; end
        class ListSchedulesResponse; end
        class ListTaskQueuePartitionsRequest; end
        class ListTaskQueuePartitionsResponse; end
        class ListWorkerDeploymentsRequest; end
        class ListWorkerDeploymentsResponse; end
        class ListWorkersRequest; end
        class ListWorkersResponse; end
        class ListWorkflowExecutionsRequest; end
        class ListWorkflowExecutionsResponse; end
        class ListWorkflowRulesRequest; end
        class ListWorkflowRulesResponse; end
        class PatchScheduleRequest; end
        class PatchScheduleResponse; end
        class PauseActivityRequest; end
        class PauseActivityResponse; end
        class PauseWorkflowExecutionRequest; end
        class PauseWorkflowExecutionResponse; end
        class PollActivityExecutionRequest; end
        class PollActivityExecutionResponse; end
        class PollActivityTaskQueueRequest; end
        class PollActivityTaskQueueResponse; end
        class PollNexusTaskQueueRequest; end
        class PollNexusTaskQueueResponse; end
        class PollWorkflowExecutionUpdateRequest; end
        class PollWorkflowExecutionUpdateResponse; end
        class PollWorkflowTaskQueueRequest; end
        class PollWorkflowTaskQueueResponse; end
        class QueryWorkflowRequest; end
        class QueryWorkflowResponse; end
        class RecordActivityTaskHeartbeatByIdRequest; end
        class RecordActivityTaskHeartbeatByIdResponse; end
        class RecordActivityTaskHeartbeatRequest; end
        class RecordActivityTaskHeartbeatResponse; end
        class RecordWorkerHeartbeatRequest; end
        class RecordWorkerHeartbeatResponse; end
        class RegisterNamespaceRequest; end
        class RegisterNamespaceResponse; end
        class RequestCancelActivityExecutionRequest; end
        class RequestCancelActivityExecutionResponse; end
        class RequestCancelWorkflowExecutionRequest; end
        class RequestCancelWorkflowExecutionResponse; end
        class ResetActivityRequest; end
        class ResetActivityResponse; end
        class ResetStickyTaskQueueRequest; end
        class ResetStickyTaskQueueResponse; end
        class ResetWorkflowExecutionRequest; end
        class ResetWorkflowExecutionResponse; end
        class RespondActivityTaskCanceledByIdRequest; end
        class RespondActivityTaskCanceledByIdResponse; end
        class RespondActivityTaskCanceledRequest; end
        class RespondActivityTaskCanceledResponse; end
        class RespondActivityTaskCompletedByIdRequest; end
        class RespondActivityTaskCompletedByIdResponse; end
        class RespondActivityTaskCompletedRequest; end
        class RespondActivityTaskCompletedResponse; end
        class RespondActivityTaskFailedByIdRequest; end
        class RespondActivityTaskFailedByIdResponse; end
        class RespondActivityTaskFailedRequest; end
        class RespondActivityTaskFailedResponse; end
        class RespondNexusTaskCompletedRequest; end
        class RespondNexusTaskCompletedResponse; end
        class RespondNexusTaskFailedRequest; end
        class RespondNexusTaskFailedResponse; end
        class RespondQueryTaskCompletedRequest; end
        class RespondQueryTaskCompletedResponse; end
        class RespondWorkflowTaskCompletedRequest; end
        class RespondWorkflowTaskCompletedResponse; end
        class RespondWorkflowTaskFailedRequest; end
        class RespondWorkflowTaskFailedResponse; end
        class ScanWorkflowExecutionsRequest; end
        class ScanWorkflowExecutionsResponse; end
        class SetCurrentDeploymentRequest; end
        class SetCurrentDeploymentResponse; end
        class SetWorkerDeploymentCurrentVersionRequest; end
        class SetWorkerDeploymentCurrentVersionResponse; end
        class SetWorkerDeploymentManagerRequest; end
        class SetWorkerDeploymentManagerResponse; end
        class SetWorkerDeploymentRampingVersionRequest; end
        class SetWorkerDeploymentRampingVersionResponse; end
        class ShutdownWorkerRequest; end
        class ShutdownWorkerResponse; end
        class SignalWithStartWorkflowExecutionRequest; end
        class SignalWithStartWorkflowExecutionResponse; end
        class SignalWorkflowExecutionRequest; end
        class SignalWorkflowExecutionResponse; end
        class StartActivityExecutionRequest; end
        class StartActivityExecutionResponse; end
        class StartBatchOperationRequest; end
        class StartBatchOperationResponse; end
        class StartWorkflowExecutionRequest; end
        class StartWorkflowExecutionResponse; end
        class StopBatchOperationRequest; end
        class StopBatchOperationResponse; end
        class TerminateActivityExecutionRequest; end
        class TerminateActivityExecutionResponse; end
        class TerminateWorkflowExecutionRequest; end
        class TerminateWorkflowExecutionResponse; end
        class TriggerWorkflowRuleRequest; end
        class TriggerWorkflowRuleResponse; end
        class UnpauseActivityRequest; end
        class UnpauseActivityResponse; end
        class UnpauseWorkflowExecutionRequest; end
        class UnpauseWorkflowExecutionResponse; end
        class UpdateActivityOptionsRequest; end
        class UpdateActivityOptionsResponse; end
        class UpdateNamespaceRequest; end
        class UpdateNamespaceResponse; end
        class UpdateScheduleRequest; end
        class UpdateScheduleResponse; end
        class UpdateTaskQueueConfigRequest; end
        class UpdateTaskQueueConfigResponse; end
        class UpdateWorkerBuildIdCompatibilityRequest; end
        class UpdateWorkerBuildIdCompatibilityResponse; end
        class UpdateWorkerConfigRequest; end
        class UpdateWorkerConfigResponse; end
        class UpdateWorkerDeploymentVersionMetadataRequest; end
        class UpdateWorkerDeploymentVersionMetadataResponse; end
        class UpdateWorkerVersioningRulesRequest; end
        class UpdateWorkerVersioningRulesResponse; end
        class UpdateWorkflowExecutionOptionsRequest; end
        class UpdateWorkflowExecutionOptionsResponse; end
        class UpdateWorkflowExecutionRequest; end
        class UpdateWorkflowExecutionResponse; end
      end
    end
  end
end
