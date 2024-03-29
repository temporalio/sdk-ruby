# Generated by the protocol buffer compiler.  DO NOT EDIT!
# source: temporal/api/enums/v1/common.proto

require 'google/protobuf'

Google::Protobuf::DescriptorPool.generated_pool.build do
  add_file("temporal/api/enums/v1/common.proto", :syntax => :proto3) do
    add_enum "temporal.api.enums.v1.EncodingType" do
      value :ENCODING_TYPE_UNSPECIFIED, 0
      value :ENCODING_TYPE_PROTO3, 1
      value :ENCODING_TYPE_JSON, 2
    end
    add_enum "temporal.api.enums.v1.IndexedValueType" do
      value :INDEXED_VALUE_TYPE_UNSPECIFIED, 0
      value :INDEXED_VALUE_TYPE_TEXT, 1
      value :INDEXED_VALUE_TYPE_KEYWORD, 2
      value :INDEXED_VALUE_TYPE_INT, 3
      value :INDEXED_VALUE_TYPE_DOUBLE, 4
      value :INDEXED_VALUE_TYPE_BOOL, 5
      value :INDEXED_VALUE_TYPE_DATETIME, 6
      value :INDEXED_VALUE_TYPE_KEYWORD_LIST, 7
    end
    add_enum "temporal.api.enums.v1.Severity" do
      value :SEVERITY_UNSPECIFIED, 0
      value :SEVERITY_HIGH, 1
      value :SEVERITY_MEDIUM, 2
      value :SEVERITY_LOW, 3
    end
  end
end

module Temporalio
  module Api
    module Enums
      module V1
        EncodingType = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.enums.v1.EncodingType").enummodule
        IndexedValueType = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.enums.v1.IndexedValueType").enummodule
        Severity = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.enums.v1.Severity").enummodule
      end
    end
  end
end
