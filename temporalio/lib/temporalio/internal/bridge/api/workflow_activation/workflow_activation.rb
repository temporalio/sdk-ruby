# frozen_string_literal: true
# Generated by the protocol buffer compiler.  DO NOT EDIT!
# source: temporal/sdk/core/workflow_activation/workflow_activation.proto

require 'google/protobuf'

require 'google/protobuf/timestamp_pb'
require 'google/protobuf/duration_pb'
require 'temporalio/api/failure/v1/message'
require 'temporalio/api/update/v1/message'
require 'temporalio/api/common/v1/message'
require 'temporalio/api/enums/v1/workflow'
require 'temporalio/internal/bridge/api/activity_result/activity_result'
require 'temporalio/internal/bridge/api/child_workflow/child_workflow'
require 'temporalio/internal/bridge/api/common/common'


descriptor_data = "\n?temporal/sdk/core/workflow_activation/workflow_activation.proto\x12\x1b\x63oresdk.workflow_activation\x1a\x1fgoogle/protobuf/timestamp.proto\x1a\x1egoogle/protobuf/duration.proto\x1a%temporal/api/failure/v1/message.proto\x1a$temporal/api/update/v1/message.proto\x1a$temporal/api/common/v1/message.proto\x1a$temporal/api/enums/v1/workflow.proto\x1a\x37temporal/sdk/core/activity_result/activity_result.proto\x1a\x35temporal/sdk/core/child_workflow/child_workflow.proto\x1a%temporal/sdk/core/common/common.proto\"\xc7\x02\n\x12WorkflowActivation\x12\x0e\n\x06run_id\x18\x01 \x01(\t\x12-\n\ttimestamp\x18\x02 \x01(\x0b\x32\x1a.google.protobuf.Timestamp\x12\x14\n\x0cis_replaying\x18\x03 \x01(\x08\x12\x16\n\x0ehistory_length\x18\x04 \x01(\r\x12@\n\x04jobs\x18\x05 \x03(\x0b\x32\x32.coresdk.workflow_activation.WorkflowActivationJob\x12 \n\x18\x61vailable_internal_flags\x18\x06 \x03(\r\x12\x1a\n\x12history_size_bytes\x18\x07 \x01(\x04\x12!\n\x19\x63ontinue_as_new_suggested\x18\x08 \x01(\x08\x12!\n\x19\x62uild_id_for_current_task\x18\t \x01(\t\"\xa7\t\n\x15WorkflowActivationJob\x12N\n\x13initialize_workflow\x18\x01 \x01(\x0b\x32/.coresdk.workflow_activation.InitializeWorkflowH\x00\x12<\n\nfire_timer\x18\x02 \x01(\x0b\x32&.coresdk.workflow_activation.FireTimerH\x00\x12K\n\x12update_random_seed\x18\x04 \x01(\x0b\x32-.coresdk.workflow_activation.UpdateRandomSeedH\x00\x12\x44\n\x0equery_workflow\x18\x05 \x01(\x0b\x32*.coresdk.workflow_activation.QueryWorkflowH\x00\x12\x46\n\x0f\x63\x61ncel_workflow\x18\x06 \x01(\x0b\x32+.coresdk.workflow_activation.CancelWorkflowH\x00\x12\x46\n\x0fsignal_workflow\x18\x07 \x01(\x0b\x32+.coresdk.workflow_activation.SignalWorkflowH\x00\x12H\n\x10resolve_activity\x18\x08 \x01(\x0b\x32,.coresdk.workflow_activation.ResolveActivityH\x00\x12G\n\x10notify_has_patch\x18\t \x01(\x0b\x32+.coresdk.workflow_activation.NotifyHasPatchH\x00\x12q\n&resolve_child_workflow_execution_start\x18\n \x01(\x0b\x32?.coresdk.workflow_activation.ResolveChildWorkflowExecutionStartH\x00\x12\x66\n resolve_child_workflow_execution\x18\x0b \x01(\x0b\x32:.coresdk.workflow_activation.ResolveChildWorkflowExecutionH\x00\x12\x66\n resolve_signal_external_workflow\x18\x0c \x01(\x0b\x32:.coresdk.workflow_activation.ResolveSignalExternalWorkflowH\x00\x12u\n(resolve_request_cancel_external_workflow\x18\r \x01(\x0b\x32\x41.coresdk.workflow_activation.ResolveRequestCancelExternalWorkflowH\x00\x12:\n\tdo_update\x18\x0e \x01(\x0b\x32%.coresdk.workflow_activation.DoUpdateH\x00\x12I\n\x11remove_from_cache\x18\x32 \x01(\x0b\x32,.coresdk.workflow_activation.RemoveFromCacheH\x00\x42\t\n\x07variant\"\xe3\t\n\x12InitializeWorkflow\x12\x15\n\rworkflow_type\x18\x01 \x01(\t\x12\x13\n\x0bworkflow_id\x18\x02 \x01(\t\x12\x32\n\targuments\x18\x03 \x03(\x0b\x32\x1f.temporal.api.common.v1.Payload\x12\x17\n\x0frandomness_seed\x18\x04 \x01(\x04\x12M\n\x07headers\x18\x05 \x03(\x0b\x32<.coresdk.workflow_activation.InitializeWorkflow.HeadersEntry\x12\x10\n\x08identity\x18\x06 \x01(\t\x12I\n\x14parent_workflow_info\x18\x07 \x01(\x0b\x32+.coresdk.common.NamespacedWorkflowExecution\x12=\n\x1aworkflow_execution_timeout\x18\x08 \x01(\x0b\x32\x19.google.protobuf.Duration\x12\x37\n\x14workflow_run_timeout\x18\t \x01(\x0b\x32\x19.google.protobuf.Duration\x12\x38\n\x15workflow_task_timeout\x18\n \x01(\x0b\x32\x19.google.protobuf.Duration\x12\'\n\x1f\x63ontinued_from_execution_run_id\x18\x0b \x01(\t\x12J\n\x13\x63ontinued_initiator\x18\x0c \x01(\x0e\x32-.temporal.api.enums.v1.ContinueAsNewInitiator\x12;\n\x11\x63ontinued_failure\x18\r \x01(\x0b\x32 .temporal.api.failure.v1.Failure\x12@\n\x16last_completion_result\x18\x0e \x01(\x0b\x32 .temporal.api.common.v1.Payloads\x12\x1e\n\x16\x66irst_execution_run_id\x18\x0f \x01(\t\x12\x39\n\x0cretry_policy\x18\x10 \x01(\x0b\x32#.temporal.api.common.v1.RetryPolicy\x12\x0f\n\x07\x61ttempt\x18\x11 \x01(\x05\x12\x15\n\rcron_schedule\x18\x12 \x01(\t\x12\x46\n\"workflow_execution_expiration_time\x18\x13 \x01(\x0b\x32\x1a.google.protobuf.Timestamp\x12\x45\n\"cron_schedule_to_schedule_interval\x18\x14 \x01(\x0b\x32\x19.google.protobuf.Duration\x12*\n\x04memo\x18\x15 \x01(\x0b\x32\x1c.temporal.api.common.v1.Memo\x12\x43\n\x11search_attributes\x18\x16 \x01(\x0b\x32(.temporal.api.common.v1.SearchAttributes\x12.\n\nstart_time\x18\x17 \x01(\x0b\x32\x1a.google.protobuf.Timestamp\x1aO\n\x0cHeadersEntry\x12\x0b\n\x03key\x18\x01 \x01(\t\x12.\n\x05value\x18\x02 \x01(\x0b\x32\x1f.temporal.api.common.v1.Payload:\x02\x38\x01\"\x18\n\tFireTimer\x12\x0b\n\x03seq\x18\x01 \x01(\r\"m\n\x0fResolveActivity\x12\x0b\n\x03seq\x18\x01 \x01(\r\x12;\n\x06result\x18\x02 \x01(\x0b\x32+.coresdk.activity_result.ActivityResolution\x12\x10\n\x08is_local\x18\x03 \x01(\x08\"\xd1\x02\n\"ResolveChildWorkflowExecutionStart\x12\x0b\n\x03seq\x18\x01 \x01(\r\x12[\n\tsucceeded\x18\x02 \x01(\x0b\x32\x46.coresdk.workflow_activation.ResolveChildWorkflowExecutionStartSuccessH\x00\x12X\n\x06\x66\x61iled\x18\x03 \x01(\x0b\x32\x46.coresdk.workflow_activation.ResolveChildWorkflowExecutionStartFailureH\x00\x12]\n\tcancelled\x18\x04 \x01(\x0b\x32H.coresdk.workflow_activation.ResolveChildWorkflowExecutionStartCancelledH\x00\x42\x08\n\x06status\";\n)ResolveChildWorkflowExecutionStartSuccess\x12\x0e\n\x06run_id\x18\x01 \x01(\t\"\xa6\x01\n)ResolveChildWorkflowExecutionStartFailure\x12\x13\n\x0bworkflow_id\x18\x01 \x01(\t\x12\x15\n\rworkflow_type\x18\x02 \x01(\t\x12M\n\x05\x63\x61use\x18\x03 \x01(\x0e\x32>.coresdk.child_workflow.StartChildWorkflowExecutionFailedCause\"`\n+ResolveChildWorkflowExecutionStartCancelled\x12\x31\n\x07\x66\x61ilure\x18\x01 \x01(\x0b\x32 .temporal.api.failure.v1.Failure\"i\n\x1dResolveChildWorkflowExecution\x12\x0b\n\x03seq\x18\x01 \x01(\r\x12;\n\x06result\x18\x02 \x01(\x0b\x32+.coresdk.child_workflow.ChildWorkflowResult\"+\n\x10UpdateRandomSeed\x12\x17\n\x0frandomness_seed\x18\x01 \x01(\x04\"\x84\x02\n\rQueryWorkflow\x12\x10\n\x08query_id\x18\x01 \x01(\t\x12\x12\n\nquery_type\x18\x02 \x01(\t\x12\x32\n\targuments\x18\x03 \x03(\x0b\x32\x1f.temporal.api.common.v1.Payload\x12H\n\x07headers\x18\x05 \x03(\x0b\x32\x37.coresdk.workflow_activation.QueryWorkflow.HeadersEntry\x1aO\n\x0cHeadersEntry\x12\x0b\n\x03key\x18\x01 \x01(\t\x12.\n\x05value\x18\x02 \x01(\x0b\x32\x1f.temporal.api.common.v1.Payload:\x02\x38\x01\"B\n\x0e\x43\x61ncelWorkflow\x12\x30\n\x07\x64\x65tails\x18\x01 \x03(\x0b\x32\x1f.temporal.api.common.v1.Payload\"\x83\x02\n\x0eSignalWorkflow\x12\x13\n\x0bsignal_name\x18\x01 \x01(\t\x12.\n\x05input\x18\x02 \x03(\x0b\x32\x1f.temporal.api.common.v1.Payload\x12\x10\n\x08identity\x18\x03 \x01(\t\x12I\n\x07headers\x18\x05 \x03(\x0b\x32\x38.coresdk.workflow_activation.SignalWorkflow.HeadersEntry\x1aO\n\x0cHeadersEntry\x12\x0b\n\x03key\x18\x01 \x01(\t\x12.\n\x05value\x18\x02 \x01(\x0b\x32\x1f.temporal.api.common.v1.Payload:\x02\x38\x01\"\"\n\x0eNotifyHasPatch\x12\x10\n\x08patch_id\x18\x01 \x01(\t\"_\n\x1dResolveSignalExternalWorkflow\x12\x0b\n\x03seq\x18\x01 \x01(\r\x12\x31\n\x07\x66\x61ilure\x18\x02 \x01(\x0b\x32 .temporal.api.failure.v1.Failure\"f\n$ResolveRequestCancelExternalWorkflow\x12\x0b\n\x03seq\x18\x01 \x01(\r\x12\x31\n\x07\x66\x61ilure\x18\x02 \x01(\x0b\x32 .temporal.api.failure.v1.Failure\"\xcb\x02\n\x08\x44oUpdate\x12\n\n\x02id\x18\x01 \x01(\t\x12\x1c\n\x14protocol_instance_id\x18\x02 \x01(\t\x12\x0c\n\x04name\x18\x03 \x01(\t\x12.\n\x05input\x18\x04 \x03(\x0b\x32\x1f.temporal.api.common.v1.Payload\x12\x43\n\x07headers\x18\x05 \x03(\x0b\x32\x32.coresdk.workflow_activation.DoUpdate.HeadersEntry\x12*\n\x04meta\x18\x06 \x01(\x0b\x32\x1c.temporal.api.update.v1.Meta\x12\x15\n\rrun_validator\x18\x07 \x01(\x08\x1aO\n\x0cHeadersEntry\x12\x0b\n\x03key\x18\x01 \x01(\t\x12.\n\x05value\x18\x02 \x01(\x0b\x32\x1f.temporal.api.common.v1.Payload:\x02\x38\x01\"\xc1\x02\n\x0fRemoveFromCache\x12\x0f\n\x07message\x18\x01 \x01(\t\x12K\n\x06reason\x18\x02 \x01(\x0e\x32;.coresdk.workflow_activation.RemoveFromCache.EvictionReason\"\xcf\x01\n\x0e\x45victionReason\x12\x0f\n\x0bUNSPECIFIED\x10\x00\x12\x0e\n\nCACHE_FULL\x10\x01\x12\x0e\n\nCACHE_MISS\x10\x02\x12\x12\n\x0eNONDETERMINISM\x10\x03\x12\r\n\tLANG_FAIL\x10\x04\x12\x12\n\x0eLANG_REQUESTED\x10\x05\x12\x12\n\x0eTASK_NOT_FOUND\x10\x06\x12\x15\n\x11UNHANDLED_COMMAND\x10\x07\x12\t\n\x05\x46\x41TAL\x10\x08\x12\x1f\n\x1bPAGINATION_OR_HISTORY_FETCH\x10\tB8\xea\x02\x35Temporalio::Internal::Bridge::Api::WorkflowActivationb\x06proto3"

pool = Google::Protobuf::DescriptorPool.generated_pool
pool.add_serialized_file(descriptor_data)

module Temporalio
  module Internal
    module Bridge
      module Api
        module WorkflowActivation
          WorkflowActivation = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("coresdk.workflow_activation.WorkflowActivation").msgclass
          WorkflowActivationJob = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("coresdk.workflow_activation.WorkflowActivationJob").msgclass
          InitializeWorkflow = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("coresdk.workflow_activation.InitializeWorkflow").msgclass
          FireTimer = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("coresdk.workflow_activation.FireTimer").msgclass
          ResolveActivity = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("coresdk.workflow_activation.ResolveActivity").msgclass
          ResolveChildWorkflowExecutionStart = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("coresdk.workflow_activation.ResolveChildWorkflowExecutionStart").msgclass
          ResolveChildWorkflowExecutionStartSuccess = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("coresdk.workflow_activation.ResolveChildWorkflowExecutionStartSuccess").msgclass
          ResolveChildWorkflowExecutionStartFailure = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("coresdk.workflow_activation.ResolveChildWorkflowExecutionStartFailure").msgclass
          ResolveChildWorkflowExecutionStartCancelled = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("coresdk.workflow_activation.ResolveChildWorkflowExecutionStartCancelled").msgclass
          ResolveChildWorkflowExecution = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("coresdk.workflow_activation.ResolveChildWorkflowExecution").msgclass
          UpdateRandomSeed = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("coresdk.workflow_activation.UpdateRandomSeed").msgclass
          QueryWorkflow = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("coresdk.workflow_activation.QueryWorkflow").msgclass
          CancelWorkflow = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("coresdk.workflow_activation.CancelWorkflow").msgclass
          SignalWorkflow = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("coresdk.workflow_activation.SignalWorkflow").msgclass
          NotifyHasPatch = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("coresdk.workflow_activation.NotifyHasPatch").msgclass
          ResolveSignalExternalWorkflow = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("coresdk.workflow_activation.ResolveSignalExternalWorkflow").msgclass
          ResolveRequestCancelExternalWorkflow = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("coresdk.workflow_activation.ResolveRequestCancelExternalWorkflow").msgclass
          DoUpdate = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("coresdk.workflow_activation.DoUpdate").msgclass
          RemoveFromCache = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("coresdk.workflow_activation.RemoveFromCache").msgclass
          RemoveFromCache::EvictionReason = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("coresdk.workflow_activation.RemoveFromCache.EvictionReason").enummodule
        end
      end
    end
  end
end