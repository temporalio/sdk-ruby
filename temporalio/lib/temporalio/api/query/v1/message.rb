# frozen_string_literal: true
# Generated by the protocol buffer compiler.  DO NOT EDIT!
# source: temporal/api/query/v1/message.proto

require 'google/protobuf'

require 'temporalio/api/enums/v1/query'
require 'temporalio/api/enums/v1/workflow'
require 'temporalio/api/common/v1/message'
require 'temporalio/api/failure/v1/message'


descriptor_data = "\n#temporal/api/query/v1/message.proto\x12\x15temporal.api.query.v1\x1a!temporal/api/enums/v1/query.proto\x1a$temporal/api/enums/v1/workflow.proto\x1a$temporal/api/common/v1/message.proto\x1a%temporal/api/failure/v1/message.proto\"\x89\x01\n\rWorkflowQuery\x12\x12\n\nquery_type\x18\x01 \x01(\t\x12\x34\n\nquery_args\x18\x02 \x01(\x0b\x32 .temporal.api.common.v1.Payloads\x12.\n\x06header\x18\x03 \x01(\x0b\x32\x1e.temporal.api.common.v1.Header\"\xce\x01\n\x13WorkflowQueryResult\x12;\n\x0bresult_type\x18\x01 \x01(\x0e\x32&.temporal.api.enums.v1.QueryResultType\x12\x30\n\x06\x61nswer\x18\x02 \x01(\x0b\x32 .temporal.api.common.v1.Payloads\x12\x15\n\rerror_message\x18\x03 \x01(\t\x12\x31\n\x07\x66\x61ilure\x18\x04 \x01(\x0b\x32 .temporal.api.failure.v1.Failure\"O\n\rQueryRejected\x12>\n\x06status\x18\x01 \x01(\x0e\x32..temporal.api.enums.v1.WorkflowExecutionStatusB\x84\x01\n\x18io.temporal.api.query.v1B\x0cMessageProtoP\x01Z!go.temporal.io/api/query/v1;query\xaa\x02\x17Temporalio.Api.Query.V1\xea\x02\x1aTemporalio::Api::Query::V1b\x06proto3"

pool = ::Google::Protobuf::DescriptorPool.generated_pool
pool.add_serialized_file(descriptor_data)

module Temporalio
  module Api
    module Query
      module V1
        WorkflowQuery = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.query.v1.WorkflowQuery").msgclass
        WorkflowQueryResult = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.query.v1.WorkflowQueryResult").msgclass
        QueryRejected = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.query.v1.QueryRejected").msgclass
      end
    end
  end
end
