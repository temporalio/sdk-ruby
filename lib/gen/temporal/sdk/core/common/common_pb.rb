# Generated by the protocol buffer compiler.  DO NOT EDIT!
# source: temporal/sdk/core/common/common.proto

require 'google/protobuf'

require 'google/protobuf/duration_pb'

Google::Protobuf::DescriptorPool.generated_pool.build do
  add_file("temporal/sdk/core/common/common.proto", :syntax => :proto3) do
    add_message "coresdk.common.NamespacedWorkflowExecution" do
      optional :namespace, :string, 1
      optional :workflow_id, :string, 2
      optional :run_id, :string, 3
    end
  end
end

module Coresdk
  module Common
    NamespacedWorkflowExecution = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("coresdk.common.NamespacedWorkflowExecution").msgclass
  end
end
