# frozen_string_literal: true
# Generated by the protocol buffer compiler.  DO NOT EDIT!
# source: temporal/api/enums/v1/namespace.proto

require 'google/protobuf'


descriptor_data = "\n%temporal/api/enums/v1/namespace.proto\x12\x15temporal.api.enums.v1*\x8e\x01\n\x0eNamespaceState\x12\x1f\n\x1bNAMESPACE_STATE_UNSPECIFIED\x10\x00\x12\x1e\n\x1aNAMESPACE_STATE_REGISTERED\x10\x01\x12\x1e\n\x1aNAMESPACE_STATE_DEPRECATED\x10\x02\x12\x1b\n\x17NAMESPACE_STATE_DELETED\x10\x03*h\n\rArchivalState\x12\x1e\n\x1a\x41RCHIVAL_STATE_UNSPECIFIED\x10\x00\x12\x1b\n\x17\x41RCHIVAL_STATE_DISABLED\x10\x01\x12\x1a\n\x16\x41RCHIVAL_STATE_ENABLED\x10\x02*s\n\x10ReplicationState\x12!\n\x1dREPLICATION_STATE_UNSPECIFIED\x10\x00\x12\x1c\n\x18REPLICATION_STATE_NORMAL\x10\x01\x12\x1e\n\x1aREPLICATION_STATE_HANDOVER\x10\x02\x42\x86\x01\n\x18io.temporal.api.enums.v1B\x0eNamespaceProtoP\x01Z!go.temporal.io/api/enums/v1;enums\xaa\x02\x17Temporalio.Api.Enums.V1\xea\x02\x1aTemporalio::Api::Enums::V1b\x06proto3"

pool = ::Google::Protobuf::DescriptorPool.generated_pool
pool.add_serialized_file(descriptor_data)

module Temporalio
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
