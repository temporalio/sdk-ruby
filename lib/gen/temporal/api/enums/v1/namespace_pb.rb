# Generated by the protocol buffer compiler.  DO NOT EDIT!
# source: temporal/api/enums/v1/namespace.proto

require 'google/protobuf'

Google::Protobuf::DescriptorPool.generated_pool.build do
  add_file("temporal/api/enums/v1/namespace.proto", :syntax => :proto3) do
    add_enum "temporal.api.enums.v1.NamespaceState" do
      value :NAMESPACE_STATE_UNSPECIFIED, 0
      value :NAMESPACE_STATE_REGISTERED, 1
      value :NAMESPACE_STATE_DEPRECATED, 2
      value :NAMESPACE_STATE_DELETED, 3
    end
    add_enum "temporal.api.enums.v1.ArchivalState" do
      value :ARCHIVAL_STATE_UNSPECIFIED, 0
      value :ARCHIVAL_STATE_DISABLED, 1
      value :ARCHIVAL_STATE_ENABLED, 2
    end
    add_enum "temporal.api.enums.v1.ReplicationState" do
      value :REPLICATION_STATE_UNSPECIFIED, 0
      value :REPLICATION_STATE_NORMAL, 1
      value :REPLICATION_STATE_HANDOVER, 2
    end
  end
end

module Temporal
  module Api
    module Enums
      module V1
        NamespaceState = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.enums.v1.NamespaceState").enummodule
        ArchivalState = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.enums.v1.ArchivalState").enummodule
        ReplicationState = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.enums.v1.ReplicationState").enummodule
      end
    end
  end
end
