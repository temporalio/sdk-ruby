# Generated by the protocol buffer compiler.  DO NOT EDIT!
# source: temporal/api/schedule/v1/message.proto

require 'google/protobuf'

require 'google/protobuf/duration_pb'
require 'google/protobuf/timestamp_pb'
require 'dependencies/gogoproto/gogo_pb'
require 'temporal/api/common/v1/message_pb'
require 'temporal/api/enums/v1/schedule_pb'
require 'temporal/api/workflow/v1/message_pb'

Google::Protobuf::DescriptorPool.generated_pool.build do
  add_file("temporal/api/schedule/v1/message.proto", :syntax => :proto3) do
    add_message "temporal.api.schedule.v1.CalendarSpec" do
      optional :second, :string, 1
      optional :minute, :string, 2
      optional :hour, :string, 3
      optional :day_of_month, :string, 4
      optional :month, :string, 5
      optional :year, :string, 6
      optional :day_of_week, :string, 7
      optional :comment, :string, 8
    end
    add_message "temporal.api.schedule.v1.Range" do
      optional :start, :int32, 1
      optional :end, :int32, 2
      optional :step, :int32, 3
    end
    add_message "temporal.api.schedule.v1.StructuredCalendarSpec" do
      repeated :second, :message, 1, "temporal.api.schedule.v1.Range"
      repeated :minute, :message, 2, "temporal.api.schedule.v1.Range"
      repeated :hour, :message, 3, "temporal.api.schedule.v1.Range"
      repeated :day_of_month, :message, 4, "temporal.api.schedule.v1.Range"
      repeated :month, :message, 5, "temporal.api.schedule.v1.Range"
      repeated :year, :message, 6, "temporal.api.schedule.v1.Range"
      repeated :day_of_week, :message, 7, "temporal.api.schedule.v1.Range"
      optional :comment, :string, 8
    end
    add_message "temporal.api.schedule.v1.IntervalSpec" do
      optional :interval, :message, 1, "google.protobuf.Duration"
      optional :phase, :message, 2, "google.protobuf.Duration"
    end
    add_message "temporal.api.schedule.v1.ScheduleSpec" do
      repeated :structured_calendar, :message, 7, "temporal.api.schedule.v1.StructuredCalendarSpec"
      repeated :cron_string, :string, 8
      repeated :calendar, :message, 1, "temporal.api.schedule.v1.CalendarSpec"
      repeated :interval, :message, 2, "temporal.api.schedule.v1.IntervalSpec"
      repeated :exclude_calendar, :message, 3, "temporal.api.schedule.v1.CalendarSpec"
      repeated :exclude_structured_calendar, :message, 9, "temporal.api.schedule.v1.StructuredCalendarSpec"
      optional :start_time, :message, 4, "google.protobuf.Timestamp"
      optional :end_time, :message, 5, "google.protobuf.Timestamp"
      optional :jitter, :message, 6, "google.protobuf.Duration"
      optional :timezone_name, :string, 10
      optional :timezone_data, :bytes, 11
    end
    add_message "temporal.api.schedule.v1.SchedulePolicies" do
      optional :overlap_policy, :enum, 1, "temporal.api.enums.v1.ScheduleOverlapPolicy"
      optional :catchup_window, :message, 2, "google.protobuf.Duration"
      optional :pause_on_failure, :bool, 3
    end
    add_message "temporal.api.schedule.v1.ScheduleAction" do
      oneof :action do
        optional :start_workflow, :message, 1, "temporal.api.workflow.v1.NewWorkflowExecutionInfo"
      end
    end
    add_message "temporal.api.schedule.v1.ScheduleActionResult" do
      optional :schedule_time, :message, 1, "google.protobuf.Timestamp"
      optional :actual_time, :message, 2, "google.protobuf.Timestamp"
      optional :start_workflow_result, :message, 11, "temporal.api.common.v1.WorkflowExecution"
    end
    add_message "temporal.api.schedule.v1.ScheduleState" do
      optional :notes, :string, 1
      optional :paused, :bool, 2
      optional :limited_actions, :bool, 3
      optional :remaining_actions, :int64, 4
    end
    add_message "temporal.api.schedule.v1.TriggerImmediatelyRequest" do
      optional :overlap_policy, :enum, 1, "temporal.api.enums.v1.ScheduleOverlapPolicy"
    end
    add_message "temporal.api.schedule.v1.BackfillRequest" do
      optional :start_time, :message, 1, "google.protobuf.Timestamp"
      optional :end_time, :message, 2, "google.protobuf.Timestamp"
      optional :overlap_policy, :enum, 3, "temporal.api.enums.v1.ScheduleOverlapPolicy"
    end
    add_message "temporal.api.schedule.v1.SchedulePatch" do
      optional :trigger_immediately, :message, 1, "temporal.api.schedule.v1.TriggerImmediatelyRequest"
      repeated :backfill_request, :message, 2, "temporal.api.schedule.v1.BackfillRequest"
      optional :pause, :string, 3
      optional :unpause, :string, 4
    end
    add_message "temporal.api.schedule.v1.ScheduleInfo" do
      optional :action_count, :int64, 1
      optional :missed_catchup_window, :int64, 2
      optional :overlap_skipped, :int64, 3
      repeated :running_workflows, :message, 9, "temporal.api.common.v1.WorkflowExecution"
      repeated :recent_actions, :message, 4, "temporal.api.schedule.v1.ScheduleActionResult"
      repeated :future_action_times, :message, 5, "google.protobuf.Timestamp"
      optional :create_time, :message, 6, "google.protobuf.Timestamp"
      optional :update_time, :message, 7, "google.protobuf.Timestamp"
      optional :invalid_schedule_error, :string, 8
    end
    add_message "temporal.api.schedule.v1.Schedule" do
      optional :spec, :message, 1, "temporal.api.schedule.v1.ScheduleSpec"
      optional :action, :message, 2, "temporal.api.schedule.v1.ScheduleAction"
      optional :policies, :message, 3, "temporal.api.schedule.v1.SchedulePolicies"
      optional :state, :message, 4, "temporal.api.schedule.v1.ScheduleState"
    end
    add_message "temporal.api.schedule.v1.ScheduleListInfo" do
      optional :spec, :message, 1, "temporal.api.schedule.v1.ScheduleSpec"
      optional :workflow_type, :message, 2, "temporal.api.common.v1.WorkflowType"
      optional :notes, :string, 3
      optional :paused, :bool, 4
      repeated :recent_actions, :message, 5, "temporal.api.schedule.v1.ScheduleActionResult"
      repeated :future_action_times, :message, 6, "google.protobuf.Timestamp"
    end
    add_message "temporal.api.schedule.v1.ScheduleListEntry" do
      optional :schedule_id, :string, 1
      optional :memo, :message, 2, "temporal.api.common.v1.Memo"
      optional :search_attributes, :message, 3, "temporal.api.common.v1.SearchAttributes"
      optional :info, :message, 4, "temporal.api.schedule.v1.ScheduleListInfo"
    end
  end
end

module Temporalio
  module Api
    module Schedule
      module V1
        CalendarSpec = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.schedule.v1.CalendarSpec").msgclass
        Range = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.schedule.v1.Range").msgclass
        StructuredCalendarSpec = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.schedule.v1.StructuredCalendarSpec").msgclass
        IntervalSpec = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.schedule.v1.IntervalSpec").msgclass
        ScheduleSpec = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.schedule.v1.ScheduleSpec").msgclass
        SchedulePolicies = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.schedule.v1.SchedulePolicies").msgclass
        ScheduleAction = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.schedule.v1.ScheduleAction").msgclass
        ScheduleActionResult = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.schedule.v1.ScheduleActionResult").msgclass
        ScheduleState = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.schedule.v1.ScheduleState").msgclass
        TriggerImmediatelyRequest = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.schedule.v1.TriggerImmediatelyRequest").msgclass
        BackfillRequest = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.schedule.v1.BackfillRequest").msgclass
        SchedulePatch = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.schedule.v1.SchedulePatch").msgclass
        ScheduleInfo = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.schedule.v1.ScheduleInfo").msgclass
        Schedule = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.schedule.v1.Schedule").msgclass
        ScheduleListInfo = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.schedule.v1.ScheduleListInfo").msgclass
        ScheduleListEntry = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.schedule.v1.ScheduleListEntry").msgclass
      end
    end
  end
end
