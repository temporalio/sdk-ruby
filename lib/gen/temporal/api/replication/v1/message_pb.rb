# Generated by the protocol buffer compiler.  DO NOT EDIT!
# source: temporal/api/replication/v1/message.proto

require 'google/protobuf'

require 'google/protobuf/timestamp_pb'
require 'dependencies/gogoproto/gogo_pb'
require 'temporal/api/enums/v1/namespace_pb'

Google::Protobuf::DescriptorPool.generated_pool.build do
  add_file("temporal/api/replication/v1/message.proto", :syntax => :proto3) do
    add_message "temporal.api.replication.v1.ClusterReplicationConfig" do
      optional :cluster_name, :string, 1
    end
    add_message "temporal.api.replication.v1.NamespaceReplicationConfig" do
      optional :active_cluster_name, :string, 1
      repeated :clusters, :message, 2, "temporal.api.replication.v1.ClusterReplicationConfig"
      optional :state, :enum, 3, "temporal.api.enums.v1.ReplicationState"
    end
    add_message "temporal.api.replication.v1.FailoverStatus" do
      optional :failover_time, :message, 1, "google.protobuf.Timestamp"
      optional :failover_version, :int64, 2
    end
  end
end

module Temporal
  module Api
    module Replication
      module V1
        ClusterReplicationConfig = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.replication.v1.ClusterReplicationConfig").msgclass
        NamespaceReplicationConfig = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.replication.v1.NamespaceReplicationConfig").msgclass
        FailoverStatus = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.replication.v1.FailoverStatus").msgclass
      end
    end
  end
end
