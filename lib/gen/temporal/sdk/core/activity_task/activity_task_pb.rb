# Generated by the protocol buffer compiler.  DO NOT EDIT!
# source: temporal/sdk/core/activity_task/activity_task.proto

require 'google/protobuf'

require 'google/protobuf/duration_pb'
require 'google/protobuf/timestamp_pb'
require 'temporal/api/common/v1/message_pb'
require 'temporal/sdk/core/common/common_pb'

Google::Protobuf::DescriptorPool.generated_pool.build do
  add_file("temporal/sdk/core/activity_task/activity_task.proto", :syntax => :proto3) do
    add_message "coresdk.activity_task.ActivityTask" do
      optional :task_token, :bytes, 1
      oneof :variant do
        optional :start, :message, 3, "coresdk.activity_task.Start"
        optional :cancel, :message, 4, "coresdk.activity_task.Cancel"
      end
    end
    add_message "coresdk.activity_task.Start" do
      optional :workflow_namespace, :string, 1
      optional :workflow_type, :string, 2
      optional :workflow_execution, :message, 3, "temporal.api.common.v1.WorkflowExecution"
      optional :activity_id, :string, 4
      optional :activity_type, :string, 5
      map :header_fields, :string, :message, 6, "temporal.api.common.v1.Payload"
      repeated :input, :message, 7, "temporal.api.common.v1.Payload"
      repeated :heartbeat_details, :message, 8, "temporal.api.common.v1.Payload"
      optional :scheduled_time, :message, 9, "google.protobuf.Timestamp"
      optional :current_attempt_scheduled_time, :message, 10, "google.protobuf.Timestamp"
      optional :started_time, :message, 11, "google.protobuf.Timestamp"
      optional :attempt, :uint32, 12
      optional :schedule_to_close_timeout, :message, 13, "google.protobuf.Duration"
      optional :start_to_close_timeout, :message, 14, "google.protobuf.Duration"
      optional :heartbeat_timeout, :message, 15, "google.protobuf.Duration"
      optional :retry_policy, :message, 16, "temporal.api.common.v1.RetryPolicy"
      optional :is_local, :bool, 17
    end
    add_message "coresdk.activity_task.Cancel" do
      optional :reason, :enum, 1, "coresdk.activity_task.ActivityCancelReason"
    end
    add_enum "coresdk.activity_task.ActivityCancelReason" do
      value :NOT_FOUND, 0
      value :CANCELLED, 1
      value :TIMED_OUT, 2
    end
  end
end

module Temporalio
  module Bridge
    module Api
      module ActivityTask
        ActivityTask = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("coresdk.activity_task.ActivityTask").msgclass
        Start = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("coresdk.activity_task.Start").msgclass
        Cancel = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("coresdk.activity_task.Cancel").msgclass
        ActivityCancelReason = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("coresdk.activity_task.ActivityCancelReason").enummodule
      end
    end
  end
end
