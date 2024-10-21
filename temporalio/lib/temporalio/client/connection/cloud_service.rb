# frozen_string_literal: true

# Generated code.  DO NOT EDIT!

require 'temporalio/api'
require 'temporalio/client/connection/service'
require 'temporalio/internal/bridge/client'

module Temporalio
  class Client
    class Connection
      # CloudService API.
      class CloudService < Service
        # @!visibility private
        def initialize(connection)
          super(connection, Internal::Bridge::Client::SERVICE_CLOUD)
        end

        # Calls CloudService.GetUsers API call.
        #
        # @param request [Temporalio::Api::Cloud::CloudService::V1::GetUsersRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::Cloud::CloudService::V1::GetUsersResponse] API response.
        def get_users(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'get_users',
            request_class: Temporalio::Api::Cloud::CloudService::V1::GetUsersRequest,
            response_class: Temporalio::Api::Cloud::CloudService::V1::GetUsersResponse,
            request:,
            rpc_options:
          )
        end

        # Calls CloudService.GetUser API call.
        #
        # @param request [Temporalio::Api::Cloud::CloudService::V1::GetUserRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::Cloud::CloudService::V1::GetUserResponse] API response.
        def get_user(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'get_user',
            request_class: Temporalio::Api::Cloud::CloudService::V1::GetUserRequest,
            response_class: Temporalio::Api::Cloud::CloudService::V1::GetUserResponse,
            request:,
            rpc_options:
          )
        end

        # Calls CloudService.CreateUser API call.
        #
        # @param request [Temporalio::Api::Cloud::CloudService::V1::CreateUserRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::Cloud::CloudService::V1::CreateUserResponse] API response.
        def create_user(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'create_user',
            request_class: Temporalio::Api::Cloud::CloudService::V1::CreateUserRequest,
            response_class: Temporalio::Api::Cloud::CloudService::V1::CreateUserResponse,
            request:,
            rpc_options:
          )
        end

        # Calls CloudService.UpdateUser API call.
        #
        # @param request [Temporalio::Api::Cloud::CloudService::V1::UpdateUserRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::Cloud::CloudService::V1::UpdateUserResponse] API response.
        def update_user(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'update_user',
            request_class: Temporalio::Api::Cloud::CloudService::V1::UpdateUserRequest,
            response_class: Temporalio::Api::Cloud::CloudService::V1::UpdateUserResponse,
            request:,
            rpc_options:
          )
        end

        # Calls CloudService.DeleteUser API call.
        #
        # @param request [Temporalio::Api::Cloud::CloudService::V1::DeleteUserRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::Cloud::CloudService::V1::DeleteUserResponse] API response.
        def delete_user(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'delete_user',
            request_class: Temporalio::Api::Cloud::CloudService::V1::DeleteUserRequest,
            response_class: Temporalio::Api::Cloud::CloudService::V1::DeleteUserResponse,
            request:,
            rpc_options:
          )
        end

        # Calls CloudService.SetUserNamespaceAccess API call.
        #
        # @param request [Temporalio::Api::Cloud::CloudService::V1::SetUserNamespaceAccessRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::Cloud::CloudService::V1::SetUserNamespaceAccessResponse] API response.
        def set_user_namespace_access(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'set_user_namespace_access',
            request_class: Temporalio::Api::Cloud::CloudService::V1::SetUserNamespaceAccessRequest,
            response_class: Temporalio::Api::Cloud::CloudService::V1::SetUserNamespaceAccessResponse,
            request:,
            rpc_options:
          )
        end

        # Calls CloudService.GetAsyncOperation API call.
        #
        # @param request [Temporalio::Api::Cloud::CloudService::V1::GetAsyncOperationRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::Cloud::CloudService::V1::GetAsyncOperationResponse] API response.
        def get_async_operation(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'get_async_operation',
            request_class: Temporalio::Api::Cloud::CloudService::V1::GetAsyncOperationRequest,
            response_class: Temporalio::Api::Cloud::CloudService::V1::GetAsyncOperationResponse,
            request:,
            rpc_options:
          )
        end

        # Calls CloudService.CreateNamespace API call.
        #
        # @param request [Temporalio::Api::Cloud::CloudService::V1::CreateNamespaceRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::Cloud::CloudService::V1::CreateNamespaceResponse] API response.
        def create_namespace(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'create_namespace',
            request_class: Temporalio::Api::Cloud::CloudService::V1::CreateNamespaceRequest,
            response_class: Temporalio::Api::Cloud::CloudService::V1::CreateNamespaceResponse,
            request:,
            rpc_options:
          )
        end

        # Calls CloudService.GetNamespaces API call.
        #
        # @param request [Temporalio::Api::Cloud::CloudService::V1::GetNamespacesRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::Cloud::CloudService::V1::GetNamespacesResponse] API response.
        def get_namespaces(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'get_namespaces',
            request_class: Temporalio::Api::Cloud::CloudService::V1::GetNamespacesRequest,
            response_class: Temporalio::Api::Cloud::CloudService::V1::GetNamespacesResponse,
            request:,
            rpc_options:
          )
        end

        # Calls CloudService.GetNamespace API call.
        #
        # @param request [Temporalio::Api::Cloud::CloudService::V1::GetNamespaceRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::Cloud::CloudService::V1::GetNamespaceResponse] API response.
        def get_namespace(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'get_namespace',
            request_class: Temporalio::Api::Cloud::CloudService::V1::GetNamespaceRequest,
            response_class: Temporalio::Api::Cloud::CloudService::V1::GetNamespaceResponse,
            request:,
            rpc_options:
          )
        end

        # Calls CloudService.UpdateNamespace API call.
        #
        # @param request [Temporalio::Api::Cloud::CloudService::V1::UpdateNamespaceRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::Cloud::CloudService::V1::UpdateNamespaceResponse] API response.
        def update_namespace(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'update_namespace',
            request_class: Temporalio::Api::Cloud::CloudService::V1::UpdateNamespaceRequest,
            response_class: Temporalio::Api::Cloud::CloudService::V1::UpdateNamespaceResponse,
            request:,
            rpc_options:
          )
        end

        # Calls CloudService.RenameCustomSearchAttribute API call.
        #
        # @param request [Temporalio::Api::Cloud::CloudService::V1::RenameCustomSearchAttributeRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::Cloud::CloudService::V1::RenameCustomSearchAttributeResponse] API response.
        def rename_custom_search_attribute(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'rename_custom_search_attribute',
            request_class: Temporalio::Api::Cloud::CloudService::V1::RenameCustomSearchAttributeRequest,
            response_class: Temporalio::Api::Cloud::CloudService::V1::RenameCustomSearchAttributeResponse,
            request:,
            rpc_options:
          )
        end

        # Calls CloudService.DeleteNamespace API call.
        #
        # @param request [Temporalio::Api::Cloud::CloudService::V1::DeleteNamespaceRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::Cloud::CloudService::V1::DeleteNamespaceResponse] API response.
        def delete_namespace(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'delete_namespace',
            request_class: Temporalio::Api::Cloud::CloudService::V1::DeleteNamespaceRequest,
            response_class: Temporalio::Api::Cloud::CloudService::V1::DeleteNamespaceResponse,
            request:,
            rpc_options:
          )
        end

        # Calls CloudService.FailoverNamespaceRegion API call.
        #
        # @param request [Temporalio::Api::Cloud::CloudService::V1::FailoverNamespaceRegionRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::Cloud::CloudService::V1::FailoverNamespaceRegionResponse] API response.
        def failover_namespace_region(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'failover_namespace_region',
            request_class: Temporalio::Api::Cloud::CloudService::V1::FailoverNamespaceRegionRequest,
            response_class: Temporalio::Api::Cloud::CloudService::V1::FailoverNamespaceRegionResponse,
            request:,
            rpc_options:
          )
        end

        # Calls CloudService.AddNamespaceRegion API call.
        #
        # @param request [Temporalio::Api::Cloud::CloudService::V1::AddNamespaceRegionRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::Cloud::CloudService::V1::AddNamespaceRegionResponse] API response.
        def add_namespace_region(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'add_namespace_region',
            request_class: Temporalio::Api::Cloud::CloudService::V1::AddNamespaceRegionRequest,
            response_class: Temporalio::Api::Cloud::CloudService::V1::AddNamespaceRegionResponse,
            request:,
            rpc_options:
          )
        end

        # Calls CloudService.GetRegions API call.
        #
        # @param request [Temporalio::Api::Cloud::CloudService::V1::GetRegionsRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::Cloud::CloudService::V1::GetRegionsResponse] API response.
        def get_regions(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'get_regions',
            request_class: Temporalio::Api::Cloud::CloudService::V1::GetRegionsRequest,
            response_class: Temporalio::Api::Cloud::CloudService::V1::GetRegionsResponse,
            request:,
            rpc_options:
          )
        end

        # Calls CloudService.GetRegion API call.
        #
        # @param request [Temporalio::Api::Cloud::CloudService::V1::GetRegionRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::Cloud::CloudService::V1::GetRegionResponse] API response.
        def get_region(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'get_region',
            request_class: Temporalio::Api::Cloud::CloudService::V1::GetRegionRequest,
            response_class: Temporalio::Api::Cloud::CloudService::V1::GetRegionResponse,
            request:,
            rpc_options:
          )
        end

        # Calls CloudService.GetApiKeys API call.
        #
        # @param request [Temporalio::Api::Cloud::CloudService::V1::GetApiKeysRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::Cloud::CloudService::V1::GetApiKeysResponse] API response.
        def get_api_keys(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'get_api_keys',
            request_class: Temporalio::Api::Cloud::CloudService::V1::GetApiKeysRequest,
            response_class: Temporalio::Api::Cloud::CloudService::V1::GetApiKeysResponse,
            request:,
            rpc_options:
          )
        end

        # Calls CloudService.GetApiKey API call.
        #
        # @param request [Temporalio::Api::Cloud::CloudService::V1::GetApiKeyRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::Cloud::CloudService::V1::GetApiKeyResponse] API response.
        def get_api_key(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'get_api_key',
            request_class: Temporalio::Api::Cloud::CloudService::V1::GetApiKeyRequest,
            response_class: Temporalio::Api::Cloud::CloudService::V1::GetApiKeyResponse,
            request:,
            rpc_options:
          )
        end

        # Calls CloudService.CreateApiKey API call.
        #
        # @param request [Temporalio::Api::Cloud::CloudService::V1::CreateApiKeyRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::Cloud::CloudService::V1::CreateApiKeyResponse] API response.
        def create_api_key(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'create_api_key',
            request_class: Temporalio::Api::Cloud::CloudService::V1::CreateApiKeyRequest,
            response_class: Temporalio::Api::Cloud::CloudService::V1::CreateApiKeyResponse,
            request:,
            rpc_options:
          )
        end

        # Calls CloudService.UpdateApiKey API call.
        #
        # @param request [Temporalio::Api::Cloud::CloudService::V1::UpdateApiKeyRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::Cloud::CloudService::V1::UpdateApiKeyResponse] API response.
        def update_api_key(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'update_api_key',
            request_class: Temporalio::Api::Cloud::CloudService::V1::UpdateApiKeyRequest,
            response_class: Temporalio::Api::Cloud::CloudService::V1::UpdateApiKeyResponse,
            request:,
            rpc_options:
          )
        end

        # Calls CloudService.DeleteApiKey API call.
        #
        # @param request [Temporalio::Api::Cloud::CloudService::V1::DeleteApiKeyRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::Cloud::CloudService::V1::DeleteApiKeyResponse] API response.
        def delete_api_key(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'delete_api_key',
            request_class: Temporalio::Api::Cloud::CloudService::V1::DeleteApiKeyRequest,
            response_class: Temporalio::Api::Cloud::CloudService::V1::DeleteApiKeyResponse,
            request:,
            rpc_options:
          )
        end

        # Calls CloudService.GetUserGroups API call.
        #
        # @param request [Temporalio::Api::Cloud::CloudService::V1::GetUserGroupsRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::Cloud::CloudService::V1::GetUserGroupsResponse] API response.
        def get_user_groups(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'get_user_groups',
            request_class: Temporalio::Api::Cloud::CloudService::V1::GetUserGroupsRequest,
            response_class: Temporalio::Api::Cloud::CloudService::V1::GetUserGroupsResponse,
            request:,
            rpc_options:
          )
        end

        # Calls CloudService.GetUserGroup API call.
        #
        # @param request [Temporalio::Api::Cloud::CloudService::V1::GetUserGroupRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::Cloud::CloudService::V1::GetUserGroupResponse] API response.
        def get_user_group(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'get_user_group',
            request_class: Temporalio::Api::Cloud::CloudService::V1::GetUserGroupRequest,
            response_class: Temporalio::Api::Cloud::CloudService::V1::GetUserGroupResponse,
            request:,
            rpc_options:
          )
        end

        # Calls CloudService.CreateUserGroup API call.
        #
        # @param request [Temporalio::Api::Cloud::CloudService::V1::CreateUserGroupRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::Cloud::CloudService::V1::CreateUserGroupResponse] API response.
        def create_user_group(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'create_user_group',
            request_class: Temporalio::Api::Cloud::CloudService::V1::CreateUserGroupRequest,
            response_class: Temporalio::Api::Cloud::CloudService::V1::CreateUserGroupResponse,
            request:,
            rpc_options:
          )
        end

        # Calls CloudService.UpdateUserGroup API call.
        #
        # @param request [Temporalio::Api::Cloud::CloudService::V1::UpdateUserGroupRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::Cloud::CloudService::V1::UpdateUserGroupResponse] API response.
        def update_user_group(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'update_user_group',
            request_class: Temporalio::Api::Cloud::CloudService::V1::UpdateUserGroupRequest,
            response_class: Temporalio::Api::Cloud::CloudService::V1::UpdateUserGroupResponse,
            request:,
            rpc_options:
          )
        end

        # Calls CloudService.DeleteUserGroup API call.
        #
        # @param request [Temporalio::Api::Cloud::CloudService::V1::DeleteUserGroupRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::Cloud::CloudService::V1::DeleteUserGroupResponse] API response.
        def delete_user_group(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'delete_user_group',
            request_class: Temporalio::Api::Cloud::CloudService::V1::DeleteUserGroupRequest,
            response_class: Temporalio::Api::Cloud::CloudService::V1::DeleteUserGroupResponse,
            request:,
            rpc_options:
          )
        end

        # Calls CloudService.SetUserGroupNamespaceAccess API call.
        #
        # @param request [Temporalio::Api::Cloud::CloudService::V1::SetUserGroupNamespaceAccessRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::Cloud::CloudService::V1::SetUserGroupNamespaceAccessResponse] API response.
        def set_user_group_namespace_access(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'set_user_group_namespace_access',
            request_class: Temporalio::Api::Cloud::CloudService::V1::SetUserGroupNamespaceAccessRequest,
            response_class: Temporalio::Api::Cloud::CloudService::V1::SetUserGroupNamespaceAccessResponse,
            request:,
            rpc_options:
          )
        end

        # Calls CloudService.CreateServiceAccount API call.
        #
        # @param request [Temporalio::Api::Cloud::CloudService::V1::CreateServiceAccountRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::Cloud::CloudService::V1::CreateServiceAccountResponse] API response.
        def create_service_account(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'create_service_account',
            request_class: Temporalio::Api::Cloud::CloudService::V1::CreateServiceAccountRequest,
            response_class: Temporalio::Api::Cloud::CloudService::V1::CreateServiceAccountResponse,
            request:,
            rpc_options:
          )
        end

        # Calls CloudService.GetServiceAccount API call.
        #
        # @param request [Temporalio::Api::Cloud::CloudService::V1::GetServiceAccountRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::Cloud::CloudService::V1::GetServiceAccountResponse] API response.
        def get_service_account(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'get_service_account',
            request_class: Temporalio::Api::Cloud::CloudService::V1::GetServiceAccountRequest,
            response_class: Temporalio::Api::Cloud::CloudService::V1::GetServiceAccountResponse,
            request:,
            rpc_options:
          )
        end

        # Calls CloudService.GetServiceAccounts API call.
        #
        # @param request [Temporalio::Api::Cloud::CloudService::V1::GetServiceAccountsRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::Cloud::CloudService::V1::GetServiceAccountsResponse] API response.
        def get_service_accounts(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'get_service_accounts',
            request_class: Temporalio::Api::Cloud::CloudService::V1::GetServiceAccountsRequest,
            response_class: Temporalio::Api::Cloud::CloudService::V1::GetServiceAccountsResponse,
            request:,
            rpc_options:
          )
        end

        # Calls CloudService.UpdateServiceAccount API call.
        #
        # @param request [Temporalio::Api::Cloud::CloudService::V1::UpdateServiceAccountRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::Cloud::CloudService::V1::UpdateServiceAccountResponse] API response.
        def update_service_account(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'update_service_account',
            request_class: Temporalio::Api::Cloud::CloudService::V1::UpdateServiceAccountRequest,
            response_class: Temporalio::Api::Cloud::CloudService::V1::UpdateServiceAccountResponse,
            request:,
            rpc_options:
          )
        end

        # Calls CloudService.DeleteServiceAccount API call.
        #
        # @param request [Temporalio::Api::Cloud::CloudService::V1::DeleteServiceAccountRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::Cloud::CloudService::V1::DeleteServiceAccountResponse] API response.
        def delete_service_account(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'delete_service_account',
            request_class: Temporalio::Api::Cloud::CloudService::V1::DeleteServiceAccountRequest,
            response_class: Temporalio::Api::Cloud::CloudService::V1::DeleteServiceAccountResponse,
            request:,
            rpc_options:
          )
        end
      end
    end
  end
end
