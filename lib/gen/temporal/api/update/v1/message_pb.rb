# Generated by the protocol buffer compiler.  DO NOT EDIT!
# source: temporal/api/update/v1/message.proto

require 'google/protobuf'

require 'temporal/api/common/v1/message_pb'

Google::Protobuf::DescriptorPool.generated_pool.build do
  add_file("temporal/api/update/v1/message.proto", :syntax => :proto3) do
    add_message "temporal.api.update.v1.WorkflowUpdate" do
      optional :header, :message, 1, "temporal.api.common.v1.Header"
      optional :name, :string, 2
      optional :args, :message, 3, "temporal.api.common.v1.Payloads"
    end
  end
end

module Temporal
  module Api
    module Update
      module V1
        WorkflowUpdate = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.update.v1.WorkflowUpdate").msgclass
      end
    end
  end
end
