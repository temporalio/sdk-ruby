# frozen_string_literal: true
# Generated by the protocol buffer compiler.  DO NOT EDIT!
# source: temporal/api/cloud/cloudservice/v1/service.proto

require 'google/protobuf'

require 'temporalio/api/cloud/cloudservice/v1/request_response'
require 'google/api/annotations_pb'


descriptor_data = "\n0temporal/api/cloud/cloudservice/v1/service.proto\x12\"temporal.api.cloud.cloudservice.v1\x1a\x39temporal/api/cloud/cloudservice/v1/request_response.proto\x1a\x1cgoogle/api/annotations.proto2\xce.\n\x0c\x43loudService\x12\x8b\x01\n\x08GetUsers\x12\x33.temporal.api.cloud.cloudservice.v1.GetUsersRequest\x1a\x34.temporal.api.cloud.cloudservice.v1.GetUsersResponse\"\x14\x82\xd3\xe4\x93\x02\x0e\x12\x0c/cloud/users\x12\x92\x01\n\x07GetUser\x12\x32.temporal.api.cloud.cloudservice.v1.GetUserRequest\x1a\x33.temporal.api.cloud.cloudservice.v1.GetUserResponse\"\x1e\x82\xd3\xe4\x93\x02\x18\x12\x16/cloud/users/{user_id}\x12\x94\x01\n\nCreateUser\x12\x35.temporal.api.cloud.cloudservice.v1.CreateUserRequest\x1a\x36.temporal.api.cloud.cloudservice.v1.CreateUserResponse\"\x17\x82\xd3\xe4\x93\x02\x11\"\x0c/cloud/users:\x01*\x12\x9e\x01\n\nUpdateUser\x12\x35.temporal.api.cloud.cloudservice.v1.UpdateUserRequest\x1a\x36.temporal.api.cloud.cloudservice.v1.UpdateUserResponse\"!\x82\xd3\xe4\x93\x02\x1b\"\x16/cloud/users/{user_id}:\x01*\x12\x9b\x01\n\nDeleteUser\x12\x35.temporal.api.cloud.cloudservice.v1.DeleteUserRequest\x1a\x36.temporal.api.cloud.cloudservice.v1.DeleteUserResponse\"\x1e\x82\xd3\xe4\x93\x02\x18*\x16/cloud/users/{user_id}\x12\xe0\x01\n\x16SetUserNamespaceAccess\x12\x41.temporal.api.cloud.cloudservice.v1.SetUserNamespaceAccessRequest\x1a\x42.temporal.api.cloud.cloudservice.v1.SetUserNamespaceAccessResponse\"?\x82\xd3\xe4\x93\x02\x39\"4/cloud/namespaces/{namespace}/users/{user_id}/access:\x01*\x12\xc0\x01\n\x11GetAsyncOperation\x12<.temporal.api.cloud.cloudservice.v1.GetAsyncOperationRequest\x1a=.temporal.api.cloud.cloudservice.v1.GetAsyncOperationResponse\".\x82\xd3\xe4\x93\x02(\x12&/cloud/operations/{async_operation_id}\x12\xa8\x01\n\x0f\x43reateNamespace\x12:.temporal.api.cloud.cloudservice.v1.CreateNamespaceRequest\x1a;.temporal.api.cloud.cloudservice.v1.CreateNamespaceResponse\"\x1c\x82\xd3\xe4\x93\x02\x16\"\x11/cloud/namespaces:\x01*\x12\x9f\x01\n\rGetNamespaces\x12\x38.temporal.api.cloud.cloudservice.v1.GetNamespacesRequest\x1a\x39.temporal.api.cloud.cloudservice.v1.GetNamespacesResponse\"\x19\x82\xd3\xe4\x93\x02\x13\x12\x11/cloud/namespaces\x12\xa8\x01\n\x0cGetNamespace\x12\x37.temporal.api.cloud.cloudservice.v1.GetNamespaceRequest\x1a\x38.temporal.api.cloud.cloudservice.v1.GetNamespaceResponse\"%\x82\xd3\xe4\x93\x02\x1f\x12\x1d/cloud/namespaces/{namespace}\x12\xb4\x01\n\x0fUpdateNamespace\x12:.temporal.api.cloud.cloudservice.v1.UpdateNamespaceRequest\x1a;.temporal.api.cloud.cloudservice.v1.UpdateNamespaceResponse\"(\x82\xd3\xe4\x93\x02\"\"\x1d/cloud/namespaces/{namespace}:\x01*\x12\xf7\x01\n\x1bRenameCustomSearchAttribute\x12\x46.temporal.api.cloud.cloudservice.v1.RenameCustomSearchAttributeRequest\x1aG.temporal.api.cloud.cloudservice.v1.RenameCustomSearchAttributeResponse\"G\x82\xd3\xe4\x93\x02\x41\"</cloud/namespaces/{namespace}/rename-custom-search-attribute:\x01*\x12\xb1\x01\n\x0f\x44\x65leteNamespace\x12:.temporal.api.cloud.cloudservice.v1.DeleteNamespaceRequest\x1a;.temporal.api.cloud.cloudservice.v1.DeleteNamespaceResponse\"%\x82\xd3\xe4\x93\x02\x1f*\x1d/cloud/namespaces/{namespace}\x12\xdc\x01\n\x17\x46\x61iloverNamespaceRegion\x12\x42.temporal.api.cloud.cloudservice.v1.FailoverNamespaceRegionRequest\x1a\x43.temporal.api.cloud.cloudservice.v1.FailoverNamespaceRegionResponse\"8\x82\xd3\xe4\x93\x02\x32\"-/cloud/namespaces/{namespace}/failover-region:\x01*\x12\xc8\x01\n\x12\x41\x64\x64NamespaceRegion\x12=.temporal.api.cloud.cloudservice.v1.AddNamespaceRegionRequest\x1a>.temporal.api.cloud.cloudservice.v1.AddNamespaceRegionResponse\"3\x82\xd3\xe4\x93\x02-\"(/cloud/namespaces/{namespace}/add-region:\x01*\x12\x93\x01\n\nGetRegions\x12\x35.temporal.api.cloud.cloudservice.v1.GetRegionsRequest\x1a\x36.temporal.api.cloud.cloudservice.v1.GetRegionsResponse\"\x16\x82\xd3\xe4\x93\x02\x10\x12\x0e/cloud/regions\x12\x99\x01\n\tGetRegion\x12\x34.temporal.api.cloud.cloudservice.v1.GetRegionRequest\x1a\x35.temporal.api.cloud.cloudservice.v1.GetRegionResponse\"\x1f\x82\xd3\xe4\x93\x02\x19\x12\x17/cloud/regions/{region}\x12\x94\x01\n\nGetApiKeys\x12\x35.temporal.api.cloud.cloudservice.v1.GetApiKeysRequest\x1a\x36.temporal.api.cloud.cloudservice.v1.GetApiKeysResponse\"\x17\x82\xd3\xe4\x93\x02\x11\x12\x0f/cloud/api-keys\x12\x9a\x01\n\tGetApiKey\x12\x34.temporal.api.cloud.cloudservice.v1.GetApiKeyRequest\x1a\x35.temporal.api.cloud.cloudservice.v1.GetApiKeyResponse\" \x82\xd3\xe4\x93\x02\x1a\x12\x18/cloud/api-keys/{key_id}\x12\x9d\x01\n\x0c\x43reateApiKey\x12\x37.temporal.api.cloud.cloudservice.v1.CreateApiKeyRequest\x1a\x38.temporal.api.cloud.cloudservice.v1.CreateApiKeyResponse\"\x1a\x82\xd3\xe4\x93\x02\x14\"\x0f/cloud/api-keys:\x01*\x12\xa6\x01\n\x0cUpdateApiKey\x12\x37.temporal.api.cloud.cloudservice.v1.UpdateApiKeyRequest\x1a\x38.temporal.api.cloud.cloudservice.v1.UpdateApiKeyResponse\"#\x82\xd3\xe4\x93\x02\x1d\"\x18/cloud/api-keys/{key_id}:\x01*\x12\xa3\x01\n\x0c\x44\x65leteApiKey\x12\x37.temporal.api.cloud.cloudservice.v1.DeleteApiKeyRequest\x1a\x38.temporal.api.cloud.cloudservice.v1.DeleteApiKeyResponse\" \x82\xd3\xe4\x93\x02\x1a*\x18/cloud/api-keys/{key_id}\x12\xa0\x01\n\rGetUserGroups\x12\x38.temporal.api.cloud.cloudservice.v1.GetUserGroupsRequest\x1a\x39.temporal.api.cloud.cloudservice.v1.GetUserGroupsResponse\"\x1a\x82\xd3\xe4\x93\x02\x14\x12\x12/cloud/user-groups\x12\xa8\x01\n\x0cGetUserGroup\x12\x37.temporal.api.cloud.cloudservice.v1.GetUserGroupRequest\x1a\x38.temporal.api.cloud.cloudservice.v1.GetUserGroupResponse\"%\x82\xd3\xe4\x93\x02\x1f\x12\x1d/cloud/user-groups/{group_id}\x12\xa9\x01\n\x0f\x43reateUserGroup\x12:.temporal.api.cloud.cloudservice.v1.CreateUserGroupRequest\x1a;.temporal.api.cloud.cloudservice.v1.CreateUserGroupResponse\"\x1d\x82\xd3\xe4\x93\x02\x17\"\x12/cloud/user-groups:\x01*\x12\xb4\x01\n\x0fUpdateUserGroup\x12:.temporal.api.cloud.cloudservice.v1.UpdateUserGroupRequest\x1a;.temporal.api.cloud.cloudservice.v1.UpdateUserGroupResponse\"(\x82\xd3\xe4\x93\x02\"\"\x1d/cloud/user-groups/{group_id}:\x01*\x12\xb1\x01\n\x0f\x44\x65leteUserGroup\x12:.temporal.api.cloud.cloudservice.v1.DeleteUserGroupRequest\x1a;.temporal.api.cloud.cloudservice.v1.DeleteUserGroupResponse\"%\x82\xd3\xe4\x93\x02\x1f*\x1d/cloud/user-groups/{group_id}\x12\xf6\x01\n\x1bSetUserGroupNamespaceAccess\x12\x46.temporal.api.cloud.cloudservice.v1.SetUserGroupNamespaceAccessRequest\x1aG.temporal.api.cloud.cloudservice.v1.SetUserGroupNamespaceAccessResponse\"F\x82\xd3\xe4\x93\x02@\";/cloud/namespaces/{namespace}/user-groups/{group_id}/access:\x01*\x12\xbd\x01\n\x14\x43reateServiceAccount\x12?.temporal.api.cloud.cloudservice.v1.CreateServiceAccountRequest\x1a@.temporal.api.cloud.cloudservice.v1.CreateServiceAccountResponse\"\"\x82\xd3\xe4\x93\x02\x1c\"\x17/cloud/service-accounts:\x01*\x12\xc6\x01\n\x11GetServiceAccount\x12<.temporal.api.cloud.cloudservice.v1.GetServiceAccountRequest\x1a=.temporal.api.cloud.cloudservice.v1.GetServiceAccountResponse\"4\x82\xd3\xe4\x93\x02.\x12,/cloud/service-accounts/{service_account_id}\x12\xb4\x01\n\x12GetServiceAccounts\x12=.temporal.api.cloud.cloudservice.v1.GetServiceAccountsRequest\x1a>.temporal.api.cloud.cloudservice.v1.GetServiceAccountsResponse\"\x1f\x82\xd3\xe4\x93\x02\x19\x12\x17/cloud/service-accounts\x12\xd2\x01\n\x14UpdateServiceAccount\x12?.temporal.api.cloud.cloudservice.v1.UpdateServiceAccountRequest\x1a@.temporal.api.cloud.cloudservice.v1.UpdateServiceAccountResponse\"7\x82\xd3\xe4\x93\x02\x31\",/cloud/service-accounts/{service_account_id}:\x01*\x12\xcf\x01\n\x14\x44\x65leteServiceAccount\x12?.temporal.api.cloud.cloudservice.v1.DeleteServiceAccountRequest\x1a@.temporal.api.cloud.cloudservice.v1.DeleteServiceAccountResponse\"4\x82\xd3\xe4\x93\x02.*,/cloud/service-accounts/{service_account_id}B\xc0\x01\n%io.temporal.api.cloud.cloudservice.v1B\x0cServiceProtoP\x01Z5go.temporal.io/api/cloud/cloudservice/v1;cloudservice\xaa\x02$Temporalio.Api.Cloud.CloudService.V1\xea\x02(Temporalio::Api::Cloud::CloudService::V1b\x06proto3"

pool = Google::Protobuf::DescriptorPool.generated_pool
pool.add_serialized_file(descriptor_data)

module Temporalio
  module Api
    module Cloud
      module CloudService
        module V1
        end
      end
    end
  end
end