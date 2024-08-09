# frozen_string_literal: true
# Generated by the protocol buffer compiler.  DO NOT EDIT!
# source: temporal/api/cloud/cloudservice/v1/request_response.proto

require 'google/protobuf'

require 'temporalio/api/cloud/operation/v1/message'
require 'temporalio/api/cloud/identity/v1/message'
require 'temporalio/api/cloud/namespace/v1/message'
require 'temporalio/api/cloud/region/v1/message'


descriptor_data = "\n9temporal/api/cloud/cloudservice/v1/request_response.proto\x12\"temporal.api.cloud.cloudservice.v1\x1a-temporal/api/cloud/operation/v1/message.proto\x1a,temporal/api/cloud/identity/v1/message.proto\x1a-temporal/api/cloud/namespace/v1/message.proto\x1a*temporal/api/cloud/region/v1/message.proto\"Z\n\x0fGetUsersRequest\x12\x11\n\tpage_size\x18\x01 \x01(\x05\x12\x12\n\npage_token\x18\x02 \x01(\t\x12\r\n\x05\x65mail\x18\x03 \x01(\t\x12\x11\n\tnamespace\x18\x04 \x01(\t\"`\n\x10GetUsersResponse\x12\x33\n\x05users\x18\x01 \x03(\x0b\x32$.temporal.api.cloud.identity.v1.User\x12\x17\n\x0fnext_page_token\x18\x02 \x01(\t\"!\n\x0eGetUserRequest\x12\x0f\n\x07user_id\x18\x01 \x01(\t\"E\n\x0fGetUserResponse\x12\x32\n\x04user\x18\x01 \x01(\x0b\x32$.temporal.api.cloud.identity.v1.User\"g\n\x11\x43reateUserRequest\x12\x36\n\x04spec\x18\x01 \x01(\x0b\x32(.temporal.api.cloud.identity.v1.UserSpec\x12\x1a\n\x12\x61sync_operation_id\x18\x02 \x01(\t\"o\n\x12\x43reateUserResponse\x12\x0f\n\x07user_id\x18\x01 \x01(\t\x12H\n\x0f\x61sync_operation\x18\x02 \x01(\x0b\x32/.temporal.api.cloud.operation.v1.AsyncOperation\"\x92\x01\n\x11UpdateUserRequest\x12\x0f\n\x07user_id\x18\x01 \x01(\t\x12\x36\n\x04spec\x18\x02 \x01(\x0b\x32(.temporal.api.cloud.identity.v1.UserSpec\x12\x18\n\x10resource_version\x18\x03 \x01(\t\x12\x1a\n\x12\x61sync_operation_id\x18\x04 \x01(\t\"^\n\x12UpdateUserResponse\x12H\n\x0f\x61sync_operation\x18\x01 \x01(\x0b\x32/.temporal.api.cloud.operation.v1.AsyncOperation\"Z\n\x11\x44\x65leteUserRequest\x12\x0f\n\x07user_id\x18\x01 \x01(\t\x12\x18\n\x10resource_version\x18\x02 \x01(\t\x12\x1a\n\x12\x61sync_operation_id\x18\x03 \x01(\t\"^\n\x12\x44\x65leteUserResponse\x12H\n\x0f\x61sync_operation\x18\x01 \x01(\x0b\x32/.temporal.api.cloud.operation.v1.AsyncOperation\"\xba\x01\n\x1dSetUserNamespaceAccessRequest\x12\x11\n\tnamespace\x18\x01 \x01(\t\x12\x0f\n\x07user_id\x18\x02 \x01(\t\x12?\n\x06\x61\x63\x63\x65ss\x18\x03 \x01(\x0b\x32/.temporal.api.cloud.identity.v1.NamespaceAccess\x12\x18\n\x10resource_version\x18\x04 \x01(\t\x12\x1a\n\x12\x61sync_operation_id\x18\x05 \x01(\t\"j\n\x1eSetUserNamespaceAccessResponse\x12H\n\x0f\x61sync_operation\x18\x01 \x01(\x0b\x32/.temporal.api.cloud.operation.v1.AsyncOperation\"6\n\x18GetAsyncOperationRequest\x12\x1a\n\x12\x61sync_operation_id\x18\x01 \x01(\t\"e\n\x19GetAsyncOperationResponse\x12H\n\x0f\x61sync_operation\x18\x01 \x01(\x0b\x32/.temporal.api.cloud.operation.v1.AsyncOperation\"r\n\x16\x43reateNamespaceRequest\x12<\n\x04spec\x18\x02 \x01(\x0b\x32..temporal.api.cloud.namespace.v1.NamespaceSpec\x12\x1a\n\x12\x61sync_operation_id\x18\x03 \x01(\t\"v\n\x17\x43reateNamespaceResponse\x12\x11\n\tnamespace\x18\x01 \x01(\t\x12H\n\x0f\x61sync_operation\x18\x02 \x01(\x0b\x32/.temporal.api.cloud.operation.v1.AsyncOperation\"K\n\x14GetNamespacesRequest\x12\x11\n\tpage_size\x18\x01 \x01(\x05\x12\x12\n\npage_token\x18\x02 \x01(\t\x12\x0c\n\x04name\x18\x03 \x01(\t\"p\n\x15GetNamespacesResponse\x12>\n\nnamespaces\x18\x01 \x03(\x0b\x32*.temporal.api.cloud.namespace.v1.Namespace\x12\x17\n\x0fnext_page_token\x18\x02 \x01(\t\"(\n\x13GetNamespaceRequest\x12\x11\n\tnamespace\x18\x01 \x01(\t\"U\n\x14GetNamespaceResponse\x12=\n\tnamespace\x18\x01 \x01(\x0b\x32*.temporal.api.cloud.namespace.v1.Namespace\"\x9f\x01\n\x16UpdateNamespaceRequest\x12\x11\n\tnamespace\x18\x01 \x01(\t\x12<\n\x04spec\x18\x02 \x01(\x0b\x32..temporal.api.cloud.namespace.v1.NamespaceSpec\x12\x18\n\x10resource_version\x18\x03 \x01(\t\x12\x1a\n\x12\x61sync_operation_id\x18\x04 \x01(\t\"c\n\x17UpdateNamespaceResponse\x12H\n\x0f\x61sync_operation\x18\x01 \x01(\x0b\x32/.temporal.api.cloud.operation.v1.AsyncOperation\"\xc6\x01\n\"RenameCustomSearchAttributeRequest\x12\x11\n\tnamespace\x18\x01 \x01(\t\x12-\n%existing_custom_search_attribute_name\x18\x02 \x01(\t\x12(\n new_custom_search_attribute_name\x18\x03 \x01(\t\x12\x18\n\x10resource_version\x18\x04 \x01(\t\x12\x1a\n\x12\x61sync_operation_id\x18\x05 \x01(\t\"o\n#RenameCustomSearchAttributeResponse\x12H\n\x0f\x61sync_operation\x18\x01 \x01(\x0b\x32/.temporal.api.cloud.operation.v1.AsyncOperation\"a\n\x16\x44\x65leteNamespaceRequest\x12\x11\n\tnamespace\x18\x01 \x01(\t\x12\x18\n\x10resource_version\x18\x02 \x01(\t\x12\x1a\n\x12\x61sync_operation_id\x18\x03 \x01(\t\"c\n\x17\x44\x65leteNamespaceResponse\x12H\n\x0f\x61sync_operation\x18\x01 \x01(\x0b\x32/.temporal.api.cloud.operation.v1.AsyncOperation\"_\n\x1e\x46\x61iloverNamespaceRegionRequest\x12\x11\n\tnamespace\x18\x01 \x01(\t\x12\x0e\n\x06region\x18\x02 \x01(\t\x12\x1a\n\x12\x61sync_operation_id\x18\x03 \x01(\t\"k\n\x1f\x46\x61iloverNamespaceRegionResponse\x12H\n\x0f\x61sync_operation\x18\x01 \x01(\x0b\x32/.temporal.api.cloud.operation.v1.AsyncOperation\"t\n\x19\x41\x64\x64NamespaceRegionRequest\x12\x11\n\tnamespace\x18\x01 \x01(\t\x12\x0e\n\x06region\x18\x02 \x01(\t\x12\x18\n\x10resource_version\x18\x03 \x01(\t\x12\x1a\n\x12\x61sync_operation_id\x18\x04 \x01(\t\"f\n\x1a\x41\x64\x64NamespaceRegionResponse\x12H\n\x0f\x61sync_operation\x18\x01 \x01(\x0b\x32/.temporal.api.cloud.operation.v1.AsyncOperation\"\x13\n\x11GetRegionsRequest\"K\n\x12GetRegionsResponse\x12\x35\n\x07regions\x18\x01 \x03(\x0b\x32$.temporal.api.cloud.region.v1.Region\"\"\n\x10GetRegionRequest\x12\x0e\n\x06region\x18\x01 \x01(\t\"I\n\x11GetRegionResponse\x12\x34\n\x06region\x18\x01 \x01(\x0b\x32$.temporal.api.cloud.region.v1.Region\"`\n\x11GetApiKeysRequest\x12\x11\n\tpage_size\x18\x01 \x01(\x05\x12\x12\n\npage_token\x18\x02 \x01(\t\x12\x10\n\x08owner_id\x18\x03 \x01(\t\x12\x12\n\nowner_type\x18\x04 \x01(\t\"g\n\x12GetApiKeysResponse\x12\x38\n\x08\x61pi_keys\x18\x01 \x03(\x0b\x32&.temporal.api.cloud.identity.v1.ApiKey\x12\x17\n\x0fnext_page_token\x18\x02 \x01(\t\"\"\n\x10GetApiKeyRequest\x12\x0e\n\x06key_id\x18\x01 \x01(\t\"L\n\x11GetApiKeyResponse\x12\x37\n\x07\x61pi_key\x18\x01 \x01(\x0b\x32&.temporal.api.cloud.identity.v1.ApiKey\"k\n\x13\x43reateApiKeyRequest\x12\x38\n\x04spec\x18\x01 \x01(\x0b\x32*.temporal.api.cloud.identity.v1.ApiKeySpec\x12\x1a\n\x12\x61sync_operation_id\x18\x02 \x01(\t\"\x7f\n\x14\x43reateApiKeyResponse\x12\x0e\n\x06key_id\x18\x01 \x01(\t\x12\r\n\x05token\x18\x02 \x01(\t\x12H\n\x0f\x61sync_operation\x18\x03 \x01(\x0b\x32/.temporal.api.cloud.operation.v1.AsyncOperation\"\x95\x01\n\x13UpdateApiKeyRequest\x12\x0e\n\x06key_id\x18\x01 \x01(\t\x12\x38\n\x04spec\x18\x02 \x01(\x0b\x32*.temporal.api.cloud.identity.v1.ApiKeySpec\x12\x18\n\x10resource_version\x18\x03 \x01(\t\x12\x1a\n\x12\x61sync_operation_id\x18\x04 \x01(\t\"`\n\x14UpdateApiKeyResponse\x12H\n\x0f\x61sync_operation\x18\x01 \x01(\x0b\x32/.temporal.api.cloud.operation.v1.AsyncOperation\"[\n\x13\x44\x65leteApiKeyRequest\x12\x0e\n\x06key_id\x18\x01 \x01(\t\x12\x18\n\x10resource_version\x18\x02 \x01(\t\x12\x1a\n\x12\x61sync_operation_id\x18\x03 \x01(\t\"`\n\x14\x44\x65leteApiKeyResponse\x12H\n\x0f\x61sync_operation\x18\x01 \x01(\x0b\x32/.temporal.api.cloud.operation.v1.AsyncOperation\"d\n\x14GetUserGroupsRequest\x12\x11\n\tpage_size\x18\x01 \x01(\x05\x12\x12\n\npage_token\x18\x02 \x01(\t\x12\x11\n\tnamespace\x18\x03 \x01(\t\x12\x12\n\ngroup_name\x18\x04 \x01(\t\"k\n\x15GetUserGroupsResponse\x12\x39\n\x06groups\x18\x01 \x03(\x0b\x32).temporal.api.cloud.identity.v1.UserGroup\x12\x17\n\x0fnext_page_token\x18\x02 \x01(\t\"\'\n\x13GetUserGroupRequest\x12\x10\n\x08group_id\x18\x01 \x01(\t\"P\n\x14GetUserGroupResponse\x12\x38\n\x05group\x18\x01 \x01(\x0b\x32).temporal.api.cloud.identity.v1.UserGroup\"q\n\x16\x43reateUserGroupRequest\x12;\n\x04spec\x18\x01 \x01(\x0b\x32-.temporal.api.cloud.identity.v1.UserGroupSpec\x12\x1a\n\x12\x61sync_operation_id\x18\x02 \x01(\t\"u\n\x17\x43reateUserGroupResponse\x12\x10\n\x08group_id\x18\x01 \x01(\t\x12H\n\x0f\x61sync_operation\x18\x02 \x01(\x0b\x32/.temporal.api.cloud.operation.v1.AsyncOperation\"\x9d\x01\n\x16UpdateUserGroupRequest\x12\x10\n\x08group_id\x18\x01 \x01(\t\x12;\n\x04spec\x18\x02 \x01(\x0b\x32-.temporal.api.cloud.identity.v1.UserGroupSpec\x12\x18\n\x10resource_version\x18\x03 \x01(\t\x12\x1a\n\x12\x61sync_operation_id\x18\x04 \x01(\t\"c\n\x17UpdateUserGroupResponse\x12H\n\x0f\x61sync_operation\x18\x01 \x01(\x0b\x32/.temporal.api.cloud.operation.v1.AsyncOperation\"`\n\x16\x44\x65leteUserGroupRequest\x12\x10\n\x08group_id\x18\x01 \x01(\t\x12\x18\n\x10resource_version\x18\x02 \x01(\t\x12\x1a\n\x12\x61sync_operation_id\x18\x03 \x01(\t\"c\n\x17\x44\x65leteUserGroupResponse\x12H\n\x0f\x61sync_operation\x18\x01 \x01(\x0b\x32/.temporal.api.cloud.operation.v1.AsyncOperation\"\xc0\x01\n\"SetUserGroupNamespaceAccessRequest\x12\x11\n\tnamespace\x18\x01 \x01(\t\x12\x10\n\x08group_id\x18\x02 \x01(\t\x12?\n\x06\x61\x63\x63\x65ss\x18\x03 \x01(\x0b\x32/.temporal.api.cloud.identity.v1.NamespaceAccess\x12\x18\n\x10resource_version\x18\x04 \x01(\t\x12\x1a\n\x12\x61sync_operation_id\x18\x05 \x01(\t\"o\n#SetUserGroupNamespaceAccessResponse\x12H\n\x0f\x61sync_operation\x18\x01 \x01(\x0b\x32/.temporal.api.cloud.operation.v1.AsyncOperation\"{\n\x1b\x43reateServiceAccountRequest\x12@\n\x04spec\x18\x01 \x01(\x0b\x32\x32.temporal.api.cloud.identity.v1.ServiceAccountSpec\x12\x1a\n\x12\x61sync_operation_id\x18\x02 \x01(\t\"\x84\x01\n\x1c\x43reateServiceAccountResponse\x12\x1a\n\x12service_account_id\x18\x01 \x01(\t\x12H\n\x0f\x61sync_operation\x18\x02 \x01(\x0b\x32/.temporal.api.cloud.operation.v1.AsyncOperation\"6\n\x18GetServiceAccountRequest\x12\x1a\n\x12service_account_id\x18\x01 \x01(\t\"d\n\x19GetServiceAccountResponse\x12G\n\x0fservice_account\x18\x01 \x01(\x0b\x32..temporal.api.cloud.identity.v1.ServiceAccount\"B\n\x19GetServiceAccountsRequest\x12\x11\n\tpage_size\x18\x01 \x01(\x05\x12\x12\n\npage_token\x18\x02 \x01(\t\"~\n\x1aGetServiceAccountsResponse\x12G\n\x0fservice_account\x18\x01 \x03(\x0b\x32..temporal.api.cloud.identity.v1.ServiceAccount\x12\x17\n\x0fnext_page_token\x18\x02 \x01(\t\"\xb1\x01\n\x1bUpdateServiceAccountRequest\x12\x1a\n\x12service_account_id\x18\x01 \x01(\t\x12@\n\x04spec\x18\x02 \x01(\x0b\x32\x32.temporal.api.cloud.identity.v1.ServiceAccountSpec\x12\x18\n\x10resource_version\x18\x03 \x01(\t\x12\x1a\n\x12\x61sync_operation_id\x18\x04 \x01(\t\"h\n\x1cUpdateServiceAccountResponse\x12H\n\x0f\x61sync_operation\x18\x01 \x01(\x0b\x32/.temporal.api.cloud.operation.v1.AsyncOperation\"o\n\x1b\x44\x65leteServiceAccountRequest\x12\x1a\n\x12service_account_id\x18\x01 \x01(\t\x12\x18\n\x10resource_version\x18\x02 \x01(\t\x12\x1a\n\x12\x61sync_operation_id\x18\x03 \x01(\t\"h\n\x1c\x44\x65leteServiceAccountResponse\x12H\n\x0f\x61sync_operation\x18\x01 \x01(\x0b\x32/.temporal.api.cloud.operation.v1.AsyncOperationB\xc8\x01\n%io.temporal.api.cloud.cloudservice.v1B\x14RequestResponseProtoP\x01Z5go.temporal.io/api/cloud/cloudservice/v1;cloudservice\xaa\x02$Temporalio.Api.Cloud.CloudService.V1\xea\x02(Temporalio::Api::Cloud::CloudService::V1b\x06proto3"

pool = Google::Protobuf::DescriptorPool.generated_pool
pool.add_serialized_file(descriptor_data)

module Temporalio
  module Api
    module Cloud
      module CloudService
        module V1
          GetUsersRequest = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.cloud.cloudservice.v1.GetUsersRequest").msgclass
          GetUsersResponse = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.cloud.cloudservice.v1.GetUsersResponse").msgclass
          GetUserRequest = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.cloud.cloudservice.v1.GetUserRequest").msgclass
          GetUserResponse = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.cloud.cloudservice.v1.GetUserResponse").msgclass
          CreateUserRequest = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.cloud.cloudservice.v1.CreateUserRequest").msgclass
          CreateUserResponse = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.cloud.cloudservice.v1.CreateUserResponse").msgclass
          UpdateUserRequest = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.cloud.cloudservice.v1.UpdateUserRequest").msgclass
          UpdateUserResponse = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.cloud.cloudservice.v1.UpdateUserResponse").msgclass
          DeleteUserRequest = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.cloud.cloudservice.v1.DeleteUserRequest").msgclass
          DeleteUserResponse = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.cloud.cloudservice.v1.DeleteUserResponse").msgclass
          SetUserNamespaceAccessRequest = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.cloud.cloudservice.v1.SetUserNamespaceAccessRequest").msgclass
          SetUserNamespaceAccessResponse = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.cloud.cloudservice.v1.SetUserNamespaceAccessResponse").msgclass
          GetAsyncOperationRequest = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.cloud.cloudservice.v1.GetAsyncOperationRequest").msgclass
          GetAsyncOperationResponse = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.cloud.cloudservice.v1.GetAsyncOperationResponse").msgclass
          CreateNamespaceRequest = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.cloud.cloudservice.v1.CreateNamespaceRequest").msgclass
          CreateNamespaceResponse = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.cloud.cloudservice.v1.CreateNamespaceResponse").msgclass
          GetNamespacesRequest = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.cloud.cloudservice.v1.GetNamespacesRequest").msgclass
          GetNamespacesResponse = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.cloud.cloudservice.v1.GetNamespacesResponse").msgclass
          GetNamespaceRequest = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.cloud.cloudservice.v1.GetNamespaceRequest").msgclass
          GetNamespaceResponse = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.cloud.cloudservice.v1.GetNamespaceResponse").msgclass
          UpdateNamespaceRequest = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.cloud.cloudservice.v1.UpdateNamespaceRequest").msgclass
          UpdateNamespaceResponse = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.cloud.cloudservice.v1.UpdateNamespaceResponse").msgclass
          RenameCustomSearchAttributeRequest = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.cloud.cloudservice.v1.RenameCustomSearchAttributeRequest").msgclass
          RenameCustomSearchAttributeResponse = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.cloud.cloudservice.v1.RenameCustomSearchAttributeResponse").msgclass
          DeleteNamespaceRequest = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.cloud.cloudservice.v1.DeleteNamespaceRequest").msgclass
          DeleteNamespaceResponse = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.cloud.cloudservice.v1.DeleteNamespaceResponse").msgclass
          FailoverNamespaceRegionRequest = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.cloud.cloudservice.v1.FailoverNamespaceRegionRequest").msgclass
          FailoverNamespaceRegionResponse = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.cloud.cloudservice.v1.FailoverNamespaceRegionResponse").msgclass
          AddNamespaceRegionRequest = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.cloud.cloudservice.v1.AddNamespaceRegionRequest").msgclass
          AddNamespaceRegionResponse = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.cloud.cloudservice.v1.AddNamespaceRegionResponse").msgclass
          GetRegionsRequest = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.cloud.cloudservice.v1.GetRegionsRequest").msgclass
          GetRegionsResponse = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.cloud.cloudservice.v1.GetRegionsResponse").msgclass
          GetRegionRequest = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.cloud.cloudservice.v1.GetRegionRequest").msgclass
          GetRegionResponse = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.cloud.cloudservice.v1.GetRegionResponse").msgclass
          GetApiKeysRequest = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.cloud.cloudservice.v1.GetApiKeysRequest").msgclass
          GetApiKeysResponse = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.cloud.cloudservice.v1.GetApiKeysResponse").msgclass
          GetApiKeyRequest = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.cloud.cloudservice.v1.GetApiKeyRequest").msgclass
          GetApiKeyResponse = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.cloud.cloudservice.v1.GetApiKeyResponse").msgclass
          CreateApiKeyRequest = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.cloud.cloudservice.v1.CreateApiKeyRequest").msgclass
          CreateApiKeyResponse = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.cloud.cloudservice.v1.CreateApiKeyResponse").msgclass
          UpdateApiKeyRequest = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.cloud.cloudservice.v1.UpdateApiKeyRequest").msgclass
          UpdateApiKeyResponse = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.cloud.cloudservice.v1.UpdateApiKeyResponse").msgclass
          DeleteApiKeyRequest = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.cloud.cloudservice.v1.DeleteApiKeyRequest").msgclass
          DeleteApiKeyResponse = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.cloud.cloudservice.v1.DeleteApiKeyResponse").msgclass
          GetUserGroupsRequest = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.cloud.cloudservice.v1.GetUserGroupsRequest").msgclass
          GetUserGroupsResponse = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.cloud.cloudservice.v1.GetUserGroupsResponse").msgclass
          GetUserGroupRequest = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.cloud.cloudservice.v1.GetUserGroupRequest").msgclass
          GetUserGroupResponse = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.cloud.cloudservice.v1.GetUserGroupResponse").msgclass
          CreateUserGroupRequest = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.cloud.cloudservice.v1.CreateUserGroupRequest").msgclass
          CreateUserGroupResponse = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.cloud.cloudservice.v1.CreateUserGroupResponse").msgclass
          UpdateUserGroupRequest = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.cloud.cloudservice.v1.UpdateUserGroupRequest").msgclass
          UpdateUserGroupResponse = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.cloud.cloudservice.v1.UpdateUserGroupResponse").msgclass
          DeleteUserGroupRequest = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.cloud.cloudservice.v1.DeleteUserGroupRequest").msgclass
          DeleteUserGroupResponse = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.cloud.cloudservice.v1.DeleteUserGroupResponse").msgclass
          SetUserGroupNamespaceAccessRequest = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.cloud.cloudservice.v1.SetUserGroupNamespaceAccessRequest").msgclass
          SetUserGroupNamespaceAccessResponse = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.cloud.cloudservice.v1.SetUserGroupNamespaceAccessResponse").msgclass
          CreateServiceAccountRequest = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.cloud.cloudservice.v1.CreateServiceAccountRequest").msgclass
          CreateServiceAccountResponse = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.cloud.cloudservice.v1.CreateServiceAccountResponse").msgclass
          GetServiceAccountRequest = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.cloud.cloudservice.v1.GetServiceAccountRequest").msgclass
          GetServiceAccountResponse = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.cloud.cloudservice.v1.GetServiceAccountResponse").msgclass
          GetServiceAccountsRequest = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.cloud.cloudservice.v1.GetServiceAccountsRequest").msgclass
          GetServiceAccountsResponse = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.cloud.cloudservice.v1.GetServiceAccountsResponse").msgclass
          UpdateServiceAccountRequest = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.cloud.cloudservice.v1.UpdateServiceAccountRequest").msgclass
          UpdateServiceAccountResponse = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.cloud.cloudservice.v1.UpdateServiceAccountResponse").msgclass
          DeleteServiceAccountRequest = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.cloud.cloudservice.v1.DeleteServiceAccountRequest").msgclass
          DeleteServiceAccountResponse = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.cloud.cloudservice.v1.DeleteServiceAccountResponse").msgclass
        end
      end
    end
  end
end
