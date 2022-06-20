# Generated by the protocol buffer compiler.  DO NOT EDIT!
# source: temporal/api/errordetails/v1/message.proto

require 'google/protobuf'

require 'temporal/api/common/v1/message_pb'
require 'temporal/api/enums/v1/failed_cause_pb'

Google::Protobuf::DescriptorPool.generated_pool.build do
  add_file("temporal/api/errordetails/v1/message.proto", :syntax => :proto3) do
    add_message "temporal.api.errordetails.v1.NotFoundFailure" do
      optional :current_cluster, :string, 1
      optional :active_cluster, :string, 2
    end
    add_message "temporal.api.errordetails.v1.WorkflowExecutionAlreadyStartedFailure" do
      optional :start_request_id, :string, 1
      optional :run_id, :string, 2
    end
    add_message "temporal.api.errordetails.v1.NamespaceNotActiveFailure" do
      optional :namespace, :string, 1
      optional :current_cluster, :string, 2
      optional :active_cluster, :string, 3
    end
    add_message "temporal.api.errordetails.v1.ClientVersionNotSupportedFailure" do
      optional :client_version, :string, 1
      optional :client_name, :string, 2
      optional :supported_versions, :string, 3
    end
    add_message "temporal.api.errordetails.v1.ServerVersionNotSupportedFailure" do
      optional :server_version, :string, 1
      optional :client_supported_server_versions, :string, 2
    end
    add_message "temporal.api.errordetails.v1.NamespaceAlreadyExistsFailure" do
    end
    add_message "temporal.api.errordetails.v1.CancellationAlreadyRequestedFailure" do
    end
    add_message "temporal.api.errordetails.v1.QueryFailedFailure" do
    end
    add_message "temporal.api.errordetails.v1.PermissionDeniedFailure" do
      optional :reason, :string, 1
    end
    add_message "temporal.api.errordetails.v1.ResourceExhaustedFailure" do
      optional :cause, :enum, 1, "temporal.api.enums.v1.ResourceExhaustedCause"
    end
    add_message "temporal.api.errordetails.v1.SystemWorkflowFailure" do
      optional :workflow_execution, :message, 1, "temporal.api.common.v1.WorkflowExecution"
      optional :workflow_error, :string, 2
    end
  end
end

module Temporal
  module Api
    module ErrorDetails
      module V1
        NotFoundFailure = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.errordetails.v1.NotFoundFailure").msgclass
        WorkflowExecutionAlreadyStartedFailure = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.errordetails.v1.WorkflowExecutionAlreadyStartedFailure").msgclass
        NamespaceNotActiveFailure = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.errordetails.v1.NamespaceNotActiveFailure").msgclass
        ClientVersionNotSupportedFailure = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.errordetails.v1.ClientVersionNotSupportedFailure").msgclass
        ServerVersionNotSupportedFailure = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.errordetails.v1.ServerVersionNotSupportedFailure").msgclass
        NamespaceAlreadyExistsFailure = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.errordetails.v1.NamespaceAlreadyExistsFailure").msgclass
        CancellationAlreadyRequestedFailure = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.errordetails.v1.CancellationAlreadyRequestedFailure").msgclass
        QueryFailedFailure = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.errordetails.v1.QueryFailedFailure").msgclass
        PermissionDeniedFailure = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.errordetails.v1.PermissionDeniedFailure").msgclass
        ResourceExhaustedFailure = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.errordetails.v1.ResourceExhaustedFailure").msgclass
        SystemWorkflowFailure = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.errordetails.v1.SystemWorkflowFailure").msgclass
      end
    end
  end
end