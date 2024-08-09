# frozen_string_literal: true
# Generated by the protocol buffer compiler.  DO NOT EDIT!
# source: temporal/api/enums/v1/event_type.proto

require 'google/protobuf'


descriptor_data = "\n&temporal/api/enums/v1/event_type.proto\x12\x15temporal.api.enums.v1*\xe8\x13\n\tEventType\x12\x1a\n\x16\x45VENT_TYPE_UNSPECIFIED\x10\x00\x12)\n%EVENT_TYPE_WORKFLOW_EXECUTION_STARTED\x10\x01\x12+\n\'EVENT_TYPE_WORKFLOW_EXECUTION_COMPLETED\x10\x02\x12(\n$EVENT_TYPE_WORKFLOW_EXECUTION_FAILED\x10\x03\x12+\n\'EVENT_TYPE_WORKFLOW_EXECUTION_TIMED_OUT\x10\x04\x12&\n\"EVENT_TYPE_WORKFLOW_TASK_SCHEDULED\x10\x05\x12$\n EVENT_TYPE_WORKFLOW_TASK_STARTED\x10\x06\x12&\n\"EVENT_TYPE_WORKFLOW_TASK_COMPLETED\x10\x07\x12&\n\"EVENT_TYPE_WORKFLOW_TASK_TIMED_OUT\x10\x08\x12#\n\x1f\x45VENT_TYPE_WORKFLOW_TASK_FAILED\x10\t\x12&\n\"EVENT_TYPE_ACTIVITY_TASK_SCHEDULED\x10\n\x12$\n EVENT_TYPE_ACTIVITY_TASK_STARTED\x10\x0b\x12&\n\"EVENT_TYPE_ACTIVITY_TASK_COMPLETED\x10\x0c\x12#\n\x1f\x45VENT_TYPE_ACTIVITY_TASK_FAILED\x10\r\x12&\n\"EVENT_TYPE_ACTIVITY_TASK_TIMED_OUT\x10\x0e\x12-\n)EVENT_TYPE_ACTIVITY_TASK_CANCEL_REQUESTED\x10\x0f\x12%\n!EVENT_TYPE_ACTIVITY_TASK_CANCELED\x10\x10\x12\x1c\n\x18\x45VENT_TYPE_TIMER_STARTED\x10\x11\x12\x1a\n\x16\x45VENT_TYPE_TIMER_FIRED\x10\x12\x12\x1d\n\x19\x45VENT_TYPE_TIMER_CANCELED\x10\x13\x12\x32\n.EVENT_TYPE_WORKFLOW_EXECUTION_CANCEL_REQUESTED\x10\x14\x12*\n&EVENT_TYPE_WORKFLOW_EXECUTION_CANCELED\x10\x15\x12\x43\n?EVENT_TYPE_REQUEST_CANCEL_EXTERNAL_WORKFLOW_EXECUTION_INITIATED\x10\x16\x12@\n<EVENT_TYPE_REQUEST_CANCEL_EXTERNAL_WORKFLOW_EXECUTION_FAILED\x10\x17\x12;\n7EVENT_TYPE_EXTERNAL_WORKFLOW_EXECUTION_CANCEL_REQUESTED\x10\x18\x12\x1e\n\x1a\x45VENT_TYPE_MARKER_RECORDED\x10\x19\x12*\n&EVENT_TYPE_WORKFLOW_EXECUTION_SIGNALED\x10\x1a\x12,\n(EVENT_TYPE_WORKFLOW_EXECUTION_TERMINATED\x10\x1b\x12\x32\n.EVENT_TYPE_WORKFLOW_EXECUTION_CONTINUED_AS_NEW\x10\x1c\x12\x37\n3EVENT_TYPE_START_CHILD_WORKFLOW_EXECUTION_INITIATED\x10\x1d\x12\x34\n0EVENT_TYPE_START_CHILD_WORKFLOW_EXECUTION_FAILED\x10\x1e\x12/\n+EVENT_TYPE_CHILD_WORKFLOW_EXECUTION_STARTED\x10\x1f\x12\x31\n-EVENT_TYPE_CHILD_WORKFLOW_EXECUTION_COMPLETED\x10 \x12.\n*EVENT_TYPE_CHILD_WORKFLOW_EXECUTION_FAILED\x10!\x12\x30\n,EVENT_TYPE_CHILD_WORKFLOW_EXECUTION_CANCELED\x10\"\x12\x31\n-EVENT_TYPE_CHILD_WORKFLOW_EXECUTION_TIMED_OUT\x10#\x12\x32\n.EVENT_TYPE_CHILD_WORKFLOW_EXECUTION_TERMINATED\x10$\x12;\n7EVENT_TYPE_SIGNAL_EXTERNAL_WORKFLOW_EXECUTION_INITIATED\x10%\x12\x38\n4EVENT_TYPE_SIGNAL_EXTERNAL_WORKFLOW_EXECUTION_FAILED\x10&\x12\x33\n/EVENT_TYPE_EXTERNAL_WORKFLOW_EXECUTION_SIGNALED\x10\'\x12\x30\n,EVENT_TYPE_UPSERT_WORKFLOW_SEARCH_ATTRIBUTES\x10(\x12\x31\n-EVENT_TYPE_WORKFLOW_EXECUTION_UPDATE_ACCEPTED\x10)\x12\x31\n-EVENT_TYPE_WORKFLOW_EXECUTION_UPDATE_REJECTED\x10*\x12\x32\n.EVENT_TYPE_WORKFLOW_EXECUTION_UPDATE_COMPLETED\x10+\x12\x36\n2EVENT_TYPE_WORKFLOW_PROPERTIES_MODIFIED_EXTERNALLY\x10,\x12\x36\n2EVENT_TYPE_ACTIVITY_PROPERTIES_MODIFIED_EXTERNALLY\x10-\x12+\n\'EVENT_TYPE_WORKFLOW_PROPERTIES_MODIFIED\x10.\x12\x31\n-EVENT_TYPE_WORKFLOW_EXECUTION_UPDATE_ADMITTED\x10/\x12(\n$EVENT_TYPE_NEXUS_OPERATION_SCHEDULED\x10\x30\x12&\n\"EVENT_TYPE_NEXUS_OPERATION_STARTED\x10\x31\x12(\n$EVENT_TYPE_NEXUS_OPERATION_COMPLETED\x10\x32\x12%\n!EVENT_TYPE_NEXUS_OPERATION_FAILED\x10\x33\x12\'\n#EVENT_TYPE_NEXUS_OPERATION_CANCELED\x10\x34\x12(\n$EVENT_TYPE_NEXUS_OPERATION_TIMED_OUT\x10\x35\x12/\n+EVENT_TYPE_NEXUS_OPERATION_CANCEL_REQUESTED\x10\x36\x42\x86\x01\n\x18io.temporal.api.enums.v1B\x0e\x45ventTypeProtoP\x01Z!go.temporal.io/api/enums/v1;enums\xaa\x02\x17Temporalio.Api.Enums.V1\xea\x02\x1aTemporalio::Api::Enums::V1b\x06proto3"

pool = Google::Protobuf::DescriptorPool.generated_pool
pool.add_serialized_file(descriptor_data)

module Temporalio
  module Api
    module Enums
      module V1
        EventType = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.enums.v1.EventType").enummodule
      end
    end
  end
end
