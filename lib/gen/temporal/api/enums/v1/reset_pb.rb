# Generated by the protocol buffer compiler.  DO NOT EDIT!
# source: temporal/api/enums/v1/reset.proto

require 'google/protobuf'

Google::Protobuf::DescriptorPool.generated_pool.build do
  add_file("temporal/api/enums/v1/reset.proto", :syntax => :proto3) do
    add_enum "temporal.api.enums.v1.ResetReapplyType" do
      value :RESET_REAPPLY_TYPE_UNSPECIFIED, 0
      value :RESET_REAPPLY_TYPE_SIGNAL, 1
      value :RESET_REAPPLY_TYPE_NONE, 2
    end
  end
end

module Temporalio
  module Api
    module Enums
      module V1
        ResetReapplyType = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.enums.v1.ResetReapplyType").enummodule
      end
    end
  end
end
