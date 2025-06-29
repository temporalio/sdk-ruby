# frozen_string_literal: true
# Generated by the protocol buffer compiler.  DO NOT EDIT!
# source: temporal/sdk/core/common/common.proto

require 'google/protobuf'

require 'google/protobuf/duration_pb'


descriptor_data = "\n%temporal/sdk/core/common/common.proto\x12\x0e\x63oresdk.common\x1a\x1egoogle/protobuf/duration.proto\"U\n\x1bNamespacedWorkflowExecution\x12\x11\n\tnamespace\x18\x01 \x01(\t\x12\x13\n\x0bworkflow_id\x18\x02 \x01(\t\x12\x0e\n\x06run_id\x18\x03 \x01(\t\"D\n\x17WorkerDeploymentVersion\x12\x17\n\x0f\x64\x65ployment_name\x18\x01 \x01(\t\x12\x10\n\x08\x62uild_id\x18\x02 \x01(\t*@\n\x10VersioningIntent\x12\x0f\n\x0bUNSPECIFIED\x10\x00\x12\x0e\n\nCOMPATIBLE\x10\x01\x12\x0b\n\x07\x44\x45\x46\x41ULT\x10\x02\x42,\xea\x02)Temporalio::Internal::Bridge::Api::Commonb\x06proto3"

pool = ::Google::Protobuf::DescriptorPool.generated_pool
pool.add_serialized_file(descriptor_data)

module Temporalio
  module Internal
    module Bridge
      module Api
        module Common
          NamespacedWorkflowExecution = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("coresdk.common.NamespacedWorkflowExecution").msgclass
          WorkerDeploymentVersion = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("coresdk.common.WorkerDeploymentVersion").msgclass
          VersioningIntent = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("coresdk.common.VersioningIntent").enummodule
        end
      end
    end
  end
end
