# frozen_string_literal: true
# Generated by the protocol buffer compiler.  DO NOT EDIT!
# source: temporal/api/enums/v1/common.proto

require 'google/protobuf'


descriptor_data = "\n\"temporal/api/enums/v1/common.proto\x12\x15temporal.api.enums.v1*_\n\x0c\x45ncodingType\x12\x1d\n\x19\x45NCODING_TYPE_UNSPECIFIED\x10\x00\x12\x18\n\x14\x45NCODING_TYPE_PROTO3\x10\x01\x12\x16\n\x12\x45NCODING_TYPE_JSON\x10\x02*\x91\x02\n\x10IndexedValueType\x12\"\n\x1eINDEXED_VALUE_TYPE_UNSPECIFIED\x10\x00\x12\x1b\n\x17INDEXED_VALUE_TYPE_TEXT\x10\x01\x12\x1e\n\x1aINDEXED_VALUE_TYPE_KEYWORD\x10\x02\x12\x1a\n\x16INDEXED_VALUE_TYPE_INT\x10\x03\x12\x1d\n\x19INDEXED_VALUE_TYPE_DOUBLE\x10\x04\x12\x1b\n\x17INDEXED_VALUE_TYPE_BOOL\x10\x05\x12\x1f\n\x1bINDEXED_VALUE_TYPE_DATETIME\x10\x06\x12#\n\x1fINDEXED_VALUE_TYPE_KEYWORD_LIST\x10\x07*^\n\x08Severity\x12\x18\n\x14SEVERITY_UNSPECIFIED\x10\x00\x12\x11\n\rSEVERITY_HIGH\x10\x01\x12\x13\n\x0fSEVERITY_MEDIUM\x10\x02\x12\x10\n\x0cSEVERITY_LOW\x10\x03*\xde\x01\n\rCallbackState\x12\x1e\n\x1a\x43\x41LLBACK_STATE_UNSPECIFIED\x10\x00\x12\x1a\n\x16\x43\x41LLBACK_STATE_STANDBY\x10\x01\x12\x1c\n\x18\x43\x41LLBACK_STATE_SCHEDULED\x10\x02\x12\x1e\n\x1a\x43\x41LLBACK_STATE_BACKING_OFF\x10\x03\x12\x19\n\x15\x43\x41LLBACK_STATE_FAILED\x10\x04\x12\x1c\n\x18\x43\x41LLBACK_STATE_SUCCEEDED\x10\x05\x12\x1a\n\x16\x43\x41LLBACK_STATE_BLOCKED\x10\x06*\xfd\x01\n\x1aPendingNexusOperationState\x12-\n)PENDING_NEXUS_OPERATION_STATE_UNSPECIFIED\x10\x00\x12+\n\'PENDING_NEXUS_OPERATION_STATE_SCHEDULED\x10\x01\x12-\n)PENDING_NEXUS_OPERATION_STATE_BACKING_OFF\x10\x02\x12)\n%PENDING_NEXUS_OPERATION_STATE_STARTED\x10\x03\x12)\n%PENDING_NEXUS_OPERATION_STATE_BLOCKED\x10\x04*\xfe\x02\n\x1fNexusOperationCancellationState\x12\x32\n.NEXUS_OPERATION_CANCELLATION_STATE_UNSPECIFIED\x10\x00\x12\x30\n,NEXUS_OPERATION_CANCELLATION_STATE_SCHEDULED\x10\x01\x12\x32\n.NEXUS_OPERATION_CANCELLATION_STATE_BACKING_OFF\x10\x02\x12\x30\n,NEXUS_OPERATION_CANCELLATION_STATE_SUCCEEDED\x10\x03\x12-\n)NEXUS_OPERATION_CANCELLATION_STATE_FAILED\x10\x04\x12\x30\n,NEXUS_OPERATION_CANCELLATION_STATE_TIMED_OUT\x10\x05\x12.\n*NEXUS_OPERATION_CANCELLATION_STATE_BLOCKED\x10\x06\x42\x83\x01\n\x18io.temporal.api.enums.v1B\x0b\x43ommonProtoP\x01Z!go.temporal.io/api/enums/v1;enums\xaa\x02\x17Temporalio.Api.Enums.V1\xea\x02\x1aTemporalio::Api::Enums::V1b\x06proto3"

pool = Google::Protobuf::DescriptorPool.generated_pool
pool.add_serialized_file(descriptor_data)

module Temporalio
  module Api
    module Enums
      module V1
        EncodingType = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.enums.v1.EncodingType").enummodule
        IndexedValueType = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.enums.v1.IndexedValueType").enummodule
        Severity = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.enums.v1.Severity").enummodule
        CallbackState = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.enums.v1.CallbackState").enummodule
        PendingNexusOperationState = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.enums.v1.PendingNexusOperationState").enummodule
        NexusOperationCancellationState = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.enums.v1.NexusOperationCancellationState").enummodule
      end
    end
  end
end
