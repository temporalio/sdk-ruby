# frozen_string_literal: true
# Generated by the protocol buffer compiler.  DO NOT EDIT!
# source: temporal/sdk/core/activity_task/activity_task.proto

require 'google/protobuf'

require 'google/protobuf/duration_pb'
require 'google/protobuf/timestamp_pb'
require 'temporalio/api/common/v1/message'
require 'temporalio/internal/bridge/api/common/common'


descriptor_data = "\n3temporal/sdk/core/activity_task/activity_task.proto\x12\x15\x63oresdk.activity_task\x1a\x1egoogle/protobuf/duration.proto\x1a\x1fgoogle/protobuf/timestamp.proto\x1a$temporal/api/common/v1/message.proto\x1a%temporal/sdk/core/common/common.proto\"\x8d\x01\n\x0c\x41\x63tivityTask\x12\x12\n\ntask_token\x18\x01 \x01(\x0c\x12-\n\x05start\x18\x03 \x01(\x0b\x32\x1c.coresdk.activity_task.StartH\x00\x12/\n\x06\x63\x61ncel\x18\x04 \x01(\x0b\x32\x1d.coresdk.activity_task.CancelH\x00\x42\t\n\x07variant\"\xa1\x07\n\x05Start\x12\x1a\n\x12workflow_namespace\x18\x01 \x01(\t\x12\x15\n\rworkflow_type\x18\x02 \x01(\t\x12\x45\n\x12workflow_execution\x18\x03 \x01(\x0b\x32).temporal.api.common.v1.WorkflowExecution\x12\x13\n\x0b\x61\x63tivity_id\x18\x04 \x01(\t\x12\x15\n\ractivity_type\x18\x05 \x01(\t\x12\x45\n\rheader_fields\x18\x06 \x03(\x0b\x32..coresdk.activity_task.Start.HeaderFieldsEntry\x12.\n\x05input\x18\x07 \x03(\x0b\x32\x1f.temporal.api.common.v1.Payload\x12:\n\x11heartbeat_details\x18\x08 \x03(\x0b\x32\x1f.temporal.api.common.v1.Payload\x12\x32\n\x0escheduled_time\x18\t \x01(\x0b\x32\x1a.google.protobuf.Timestamp\x12\x42\n\x1e\x63urrent_attempt_scheduled_time\x18\n \x01(\x0b\x32\x1a.google.protobuf.Timestamp\x12\x30\n\x0cstarted_time\x18\x0b \x01(\x0b\x32\x1a.google.protobuf.Timestamp\x12\x0f\n\x07\x61ttempt\x18\x0c \x01(\r\x12<\n\x19schedule_to_close_timeout\x18\r \x01(\x0b\x32\x19.google.protobuf.Duration\x12\x39\n\x16start_to_close_timeout\x18\x0e \x01(\x0b\x32\x19.google.protobuf.Duration\x12\x34\n\x11heartbeat_timeout\x18\x0f \x01(\x0b\x32\x19.google.protobuf.Duration\x12\x39\n\x0cretry_policy\x18\x10 \x01(\x0b\x32#.temporal.api.common.v1.RetryPolicy\x12\x32\n\x08priority\x18\x12 \x01(\x0b\x32 .temporal.api.common.v1.Priority\x12\x10\n\x08is_local\x18\x11 \x01(\x08\x1aT\n\x11HeaderFieldsEntry\x12\x0b\n\x03key\x18\x01 \x01(\t\x12.\n\x05value\x18\x02 \x01(\x0b\x32\x1f.temporal.api.common.v1.Payload:\x02\x38\x01\"\x8a\x01\n\x06\x43\x61ncel\x12;\n\x06reason\x18\x01 \x01(\x0e\x32+.coresdk.activity_task.ActivityCancelReason\x12\x43\n\x07\x64\x65tails\x18\x02 \x01(\x0b\x32\x32.coresdk.activity_task.ActivityCancellationDetails\"\xa0\x01\n\x1b\x41\x63tivityCancellationDetails\x12\x14\n\x0cis_not_found\x18\x01 \x01(\x08\x12\x14\n\x0cis_cancelled\x18\x02 \x01(\x08\x12\x11\n\tis_paused\x18\x03 \x01(\x08\x12\x14\n\x0cis_timed_out\x18\x04 \x01(\x08\x12\x1a\n\x12is_worker_shutdown\x18\x05 \x01(\x08\x12\x10\n\x08is_reset\x18\x06 \x01(\x08*o\n\x14\x41\x63tivityCancelReason\x12\r\n\tNOT_FOUND\x10\x00\x12\r\n\tCANCELLED\x10\x01\x12\r\n\tTIMED_OUT\x10\x02\x12\x13\n\x0fWORKER_SHUTDOWN\x10\x03\x12\n\n\x06PAUSED\x10\x04\x12\t\n\x05RESET\x10\x05\x42\x32\xea\x02/Temporalio::Internal::Bridge::Api::ActivityTaskb\x06proto3"

pool = ::Google::Protobuf::DescriptorPool.generated_pool
pool.add_serialized_file(descriptor_data)

module Temporalio
  module Internal
    module Bridge
      module Api
        module ActivityTask
          ActivityTask = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("coresdk.activity_task.ActivityTask").msgclass
          Start = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("coresdk.activity_task.Start").msgclass
          Cancel = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("coresdk.activity_task.Cancel").msgclass
          ActivityCancellationDetails = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("coresdk.activity_task.ActivityCancellationDetails").msgclass
          ActivityCancelReason = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("coresdk.activity_task.ActivityCancelReason").enummodule
        end
      end
    end
  end
end
