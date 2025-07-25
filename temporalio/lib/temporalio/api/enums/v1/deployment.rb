# frozen_string_literal: true
# Generated by the protocol buffer compiler.  DO NOT EDIT!
# source: temporal/api/enums/v1/deployment.proto

require 'google/protobuf'


descriptor_data = "\n&temporal/api/enums/v1/deployment.proto\x12\x15temporal.api.enums.v1*\xc4\x01\n\x16\x44\x65ploymentReachability\x12\'\n#DEPLOYMENT_REACHABILITY_UNSPECIFIED\x10\x00\x12%\n!DEPLOYMENT_REACHABILITY_REACHABLE\x10\x01\x12\x31\n-DEPLOYMENT_REACHABILITY_CLOSED_WORKFLOWS_ONLY\x10\x02\x12\'\n#DEPLOYMENT_REACHABILITY_UNREACHABLE\x10\x03*\x8b\x01\n\x15VersionDrainageStatus\x12\'\n#VERSION_DRAINAGE_STATUS_UNSPECIFIED\x10\x00\x12$\n VERSION_DRAINAGE_STATUS_DRAINING\x10\x01\x12#\n\x1fVERSION_DRAINAGE_STATUS_DRAINED\x10\x02*\x8c\x01\n\x14WorkerVersioningMode\x12&\n\"WORKER_VERSIONING_MODE_UNSPECIFIED\x10\x00\x12&\n\"WORKER_VERSIONING_MODE_UNVERSIONED\x10\x01\x12$\n WORKER_VERSIONING_MODE_VERSIONED\x10\x02*\xb9\x02\n\x1dWorkerDeploymentVersionStatus\x12\x30\n,WORKER_DEPLOYMENT_VERSION_STATUS_UNSPECIFIED\x10\x00\x12-\n)WORKER_DEPLOYMENT_VERSION_STATUS_INACTIVE\x10\x01\x12,\n(WORKER_DEPLOYMENT_VERSION_STATUS_CURRENT\x10\x02\x12,\n(WORKER_DEPLOYMENT_VERSION_STATUS_RAMPING\x10\x03\x12-\n)WORKER_DEPLOYMENT_VERSION_STATUS_DRAINING\x10\x04\x12,\n(WORKER_DEPLOYMENT_VERSION_STATUS_DRAINED\x10\x05\x42\x87\x01\n\x18io.temporal.api.enums.v1B\x0f\x44\x65ploymentProtoP\x01Z!go.temporal.io/api/enums/v1;enums\xaa\x02\x17Temporalio.Api.Enums.V1\xea\x02\x1aTemporalio::Api::Enums::V1b\x06proto3"

pool = ::Google::Protobuf::DescriptorPool.generated_pool
pool.add_serialized_file(descriptor_data)

module Temporalio
  module Api
    module Enums
      module V1
        DeploymentReachability = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.enums.v1.DeploymentReachability").enummodule
        VersionDrainageStatus = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.enums.v1.VersionDrainageStatus").enummodule
        WorkerVersioningMode = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.enums.v1.WorkerVersioningMode").enummodule
        WorkerDeploymentVersionStatus = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.enums.v1.WorkerDeploymentVersionStatus").enummodule
      end
    end
  end
end
