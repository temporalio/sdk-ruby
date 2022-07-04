# Generated by the protocol buffer compiler.  DO NOT EDIT!
# source: temporal/sdk/core/workflow_completion/workflow_completion.proto

require 'google/protobuf'

require 'temporal/api/failure/v1/message_pb'
require 'temporal/sdk/core/common/common_pb'
require 'temporal/sdk/core/workflow_commands/workflow_commands_pb'

Google::Protobuf::DescriptorPool.generated_pool.build do
  add_file("temporal/sdk/core/workflow_completion/workflow_completion.proto", :syntax => :proto3) do
    add_message "coresdk.workflow_completion.WorkflowActivationCompletion" do
      optional :run_id, :string, 1
      oneof :status do
        optional :successful, :message, 2, "coresdk.workflow_completion.Success"
        optional :failed, :message, 3, "coresdk.workflow_completion.Failure"
      end
    end
    add_message "coresdk.workflow_completion.Success" do
      repeated :commands, :message, 1, "coresdk.workflow_commands.WorkflowCommand"
    end
    add_message "coresdk.workflow_completion.Failure" do
      optional :failure, :message, 1, "temporal.api.failure.v1.Failure"
    end
  end
end

module Coresdk
  module WorkflowCompletion
    WorkflowActivationCompletion = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("coresdk.workflow_completion.WorkflowActivationCompletion").msgclass
    Success = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("coresdk.workflow_completion.Success").msgclass
    Failure = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("coresdk.workflow_completion.Failure").msgclass
  end
end
