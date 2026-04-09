# typed: false
# frozen_string_literal: true

# Generated code.  DO NOT EDIT!

class Temporalio::Client::Connection::CloudService < ::Temporalio::Client::Connection::Service
  extend T::Sig

  sig { params(connection: Temporalio::Client::Connection).void }
  def initialize(connection); end

  sig { params(request: Temporalio::Api::Cloud::CloudService::V1::GetUsersRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::Cloud::CloudService::V1::GetUsersResponse) }
  def get_users(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::Cloud::CloudService::V1::GetUserRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::Cloud::CloudService::V1::GetUserResponse) }
  def get_user(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::Cloud::CloudService::V1::CreateUserRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::Cloud::CloudService::V1::CreateUserResponse) }
  def create_user(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::Cloud::CloudService::V1::UpdateUserRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::Cloud::CloudService::V1::UpdateUserResponse) }
  def update_user(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::Cloud::CloudService::V1::DeleteUserRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::Cloud::CloudService::V1::DeleteUserResponse) }
  def delete_user(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::Cloud::CloudService::V1::SetUserNamespaceAccessRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::Cloud::CloudService::V1::SetUserNamespaceAccessResponse) }
  def set_user_namespace_access(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::Cloud::CloudService::V1::GetAsyncOperationRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::Cloud::CloudService::V1::GetAsyncOperationResponse) }
  def get_async_operation(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::Cloud::CloudService::V1::CreateNamespaceRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::Cloud::CloudService::V1::CreateNamespaceResponse) }
  def create_namespace(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::Cloud::CloudService::V1::GetNamespacesRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::Cloud::CloudService::V1::GetNamespacesResponse) }
  def get_namespaces(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::Cloud::CloudService::V1::GetNamespaceRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::Cloud::CloudService::V1::GetNamespaceResponse) }
  def get_namespace(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::Cloud::CloudService::V1::UpdateNamespaceRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::Cloud::CloudService::V1::UpdateNamespaceResponse) }
  def update_namespace(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::Cloud::CloudService::V1::RenameCustomSearchAttributeRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::Cloud::CloudService::V1::RenameCustomSearchAttributeResponse) }
  def rename_custom_search_attribute(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::Cloud::CloudService::V1::DeleteNamespaceRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::Cloud::CloudService::V1::DeleteNamespaceResponse) }
  def delete_namespace(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::Cloud::CloudService::V1::FailoverNamespaceRegionRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::Cloud::CloudService::V1::FailoverNamespaceRegionResponse) }
  def failover_namespace_region(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::Cloud::CloudService::V1::AddNamespaceRegionRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::Cloud::CloudService::V1::AddNamespaceRegionResponse) }
  def add_namespace_region(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::Cloud::CloudService::V1::DeleteNamespaceRegionRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::Cloud::CloudService::V1::DeleteNamespaceRegionResponse) }
  def delete_namespace_region(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::Cloud::CloudService::V1::GetRegionsRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::Cloud::CloudService::V1::GetRegionsResponse) }
  def get_regions(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::Cloud::CloudService::V1::GetRegionRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::Cloud::CloudService::V1::GetRegionResponse) }
  def get_region(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::Cloud::CloudService::V1::GetApiKeysRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::Cloud::CloudService::V1::GetApiKeysResponse) }
  def get_api_keys(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::Cloud::CloudService::V1::GetApiKeyRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::Cloud::CloudService::V1::GetApiKeyResponse) }
  def get_api_key(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::Cloud::CloudService::V1::CreateApiKeyRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::Cloud::CloudService::V1::CreateApiKeyResponse) }
  def create_api_key(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::Cloud::CloudService::V1::UpdateApiKeyRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::Cloud::CloudService::V1::UpdateApiKeyResponse) }
  def update_api_key(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::Cloud::CloudService::V1::DeleteApiKeyRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::Cloud::CloudService::V1::DeleteApiKeyResponse) }
  def delete_api_key(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::Cloud::CloudService::V1::GetNexusEndpointsRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::Cloud::CloudService::V1::GetNexusEndpointsResponse) }
  def get_nexus_endpoints(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::Cloud::CloudService::V1::GetNexusEndpointRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::Cloud::CloudService::V1::GetNexusEndpointResponse) }
  def get_nexus_endpoint(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::Cloud::CloudService::V1::CreateNexusEndpointRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::Cloud::CloudService::V1::CreateNexusEndpointResponse) }
  def create_nexus_endpoint(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::Cloud::CloudService::V1::UpdateNexusEndpointRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::Cloud::CloudService::V1::UpdateNexusEndpointResponse) }
  def update_nexus_endpoint(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::Cloud::CloudService::V1::DeleteNexusEndpointRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::Cloud::CloudService::V1::DeleteNexusEndpointResponse) }
  def delete_nexus_endpoint(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::Cloud::CloudService::V1::GetUserGroupsRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::Cloud::CloudService::V1::GetUserGroupsResponse) }
  def get_user_groups(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::Cloud::CloudService::V1::GetUserGroupRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::Cloud::CloudService::V1::GetUserGroupResponse) }
  def get_user_group(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::Cloud::CloudService::V1::CreateUserGroupRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::Cloud::CloudService::V1::CreateUserGroupResponse) }
  def create_user_group(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::Cloud::CloudService::V1::UpdateUserGroupRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::Cloud::CloudService::V1::UpdateUserGroupResponse) }
  def update_user_group(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::Cloud::CloudService::V1::DeleteUserGroupRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::Cloud::CloudService::V1::DeleteUserGroupResponse) }
  def delete_user_group(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::Cloud::CloudService::V1::SetUserGroupNamespaceAccessRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::Cloud::CloudService::V1::SetUserGroupNamespaceAccessResponse) }
  def set_user_group_namespace_access(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::Cloud::CloudService::V1::AddUserGroupMemberRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::Cloud::CloudService::V1::AddUserGroupMemberResponse) }
  def add_user_group_member(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::Cloud::CloudService::V1::RemoveUserGroupMemberRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::Cloud::CloudService::V1::RemoveUserGroupMemberResponse) }
  def remove_user_group_member(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::Cloud::CloudService::V1::GetUserGroupMembersRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::Cloud::CloudService::V1::GetUserGroupMembersResponse) }
  def get_user_group_members(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::Cloud::CloudService::V1::CreateServiceAccountRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::Cloud::CloudService::V1::CreateServiceAccountResponse) }
  def create_service_account(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::Cloud::CloudService::V1::GetServiceAccountRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::Cloud::CloudService::V1::GetServiceAccountResponse) }
  def get_service_account(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::Cloud::CloudService::V1::GetServiceAccountsRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::Cloud::CloudService::V1::GetServiceAccountsResponse) }
  def get_service_accounts(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::Cloud::CloudService::V1::UpdateServiceAccountRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::Cloud::CloudService::V1::UpdateServiceAccountResponse) }
  def update_service_account(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::Cloud::CloudService::V1::SetServiceAccountNamespaceAccessRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::Cloud::CloudService::V1::SetServiceAccountNamespaceAccessResponse) }
  def set_service_account_namespace_access(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::Cloud::CloudService::V1::DeleteServiceAccountRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::Cloud::CloudService::V1::DeleteServiceAccountResponse) }
  def delete_service_account(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::Cloud::CloudService::V1::GetUsageRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::Cloud::CloudService::V1::GetUsageResponse) }
  def get_usage(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::Cloud::CloudService::V1::GetAccountRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::Cloud::CloudService::V1::GetAccountResponse) }
  def get_account(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::Cloud::CloudService::V1::UpdateAccountRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::Cloud::CloudService::V1::UpdateAccountResponse) }
  def update_account(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::Cloud::CloudService::V1::CreateNamespaceExportSinkRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::Cloud::CloudService::V1::CreateNamespaceExportSinkResponse) }
  def create_namespace_export_sink(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::Cloud::CloudService::V1::GetNamespaceExportSinkRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::Cloud::CloudService::V1::GetNamespaceExportSinkResponse) }
  def get_namespace_export_sink(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::Cloud::CloudService::V1::GetNamespaceExportSinksRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::Cloud::CloudService::V1::GetNamespaceExportSinksResponse) }
  def get_namespace_export_sinks(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::Cloud::CloudService::V1::UpdateNamespaceExportSinkRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::Cloud::CloudService::V1::UpdateNamespaceExportSinkResponse) }
  def update_namespace_export_sink(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::Cloud::CloudService::V1::DeleteNamespaceExportSinkRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::Cloud::CloudService::V1::DeleteNamespaceExportSinkResponse) }
  def delete_namespace_export_sink(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::Cloud::CloudService::V1::ValidateNamespaceExportSinkRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::Cloud::CloudService::V1::ValidateNamespaceExportSinkResponse) }
  def validate_namespace_export_sink(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::Cloud::CloudService::V1::UpdateNamespaceTagsRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::Cloud::CloudService::V1::UpdateNamespaceTagsResponse) }
  def update_namespace_tags(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::Cloud::CloudService::V1::CreateConnectivityRuleRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::Cloud::CloudService::V1::CreateConnectivityRuleResponse) }
  def create_connectivity_rule(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::Cloud::CloudService::V1::GetConnectivityRuleRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::Cloud::CloudService::V1::GetConnectivityRuleResponse) }
  def get_connectivity_rule(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::Cloud::CloudService::V1::GetConnectivityRulesRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::Cloud::CloudService::V1::GetConnectivityRulesResponse) }
  def get_connectivity_rules(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::Cloud::CloudService::V1::DeleteConnectivityRuleRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::Cloud::CloudService::V1::DeleteConnectivityRuleResponse) }
  def delete_connectivity_rule(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::Cloud::CloudService::V1::ValidateAccountAuditLogSinkRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::Cloud::CloudService::V1::ValidateAccountAuditLogSinkResponse) }
  def validate_account_audit_log_sink(request, rpc_options: T.unsafe(nil)); end
end
