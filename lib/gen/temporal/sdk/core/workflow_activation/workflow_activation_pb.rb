# Generated by the protocol buffer compiler.  DO NOT EDIT!
# source: temporal/sdk/core/workflow_activation/workflow_activation.proto

require 'google/protobuf'

require 'google/protobuf/timestamp_pb'
require 'google/protobuf/duration_pb'
require 'temporal/api/failure/v1/message_pb'
require 'temporal/api/common/v1/message_pb'
require 'temporal/api/enums/v1/workflow_pb'
require 'temporal/sdk/core/activity_result/activity_result_pb'
require 'temporal/sdk/core/child_workflow/child_workflow_pb'
require 'temporal/sdk/core/common/common_pb'

Google::Protobuf::DescriptorPool.generated_pool.build do
  add_file("temporal/sdk/core/workflow_activation/workflow_activation.proto", :syntax => :proto3) do
    add_message "coresdk.workflow_activation.WorkflowActivation" do
      optional :run_id, :string, 1
      optional :timestamp, :message, 2, "google.protobuf.Timestamp"
      optional :is_replaying, :bool, 3
      optional :history_length, :uint32, 4
      repeated :jobs, :message, 5, "coresdk.workflow_activation.WorkflowActivationJob"
    end
    add_message "coresdk.workflow_activation.WorkflowActivationJob" do
      oneof :variant do
        optional :start_workflow, :message, 1, "coresdk.workflow_activation.StartWorkflow"
        optional :fire_timer, :message, 2, "coresdk.workflow_activation.FireTimer"
        optional :update_random_seed, :message, 4, "coresdk.workflow_activation.UpdateRandomSeed"
        optional :query_workflow, :message, 5, "coresdk.workflow_activation.QueryWorkflow"
        optional :cancel_workflow, :message, 6, "coresdk.workflow_activation.CancelWorkflow"
        optional :signal_workflow, :message, 7, "coresdk.workflow_activation.SignalWorkflow"
        optional :resolve_activity, :message, 8, "coresdk.workflow_activation.ResolveActivity"
        optional :notify_has_patch, :message, 9, "coresdk.workflow_activation.NotifyHasPatch"
        optional :resolve_child_workflow_execution_start, :message, 10, "coresdk.workflow_activation.ResolveChildWorkflowExecutionStart"
        optional :resolve_child_workflow_execution, :message, 11, "coresdk.workflow_activation.ResolveChildWorkflowExecution"
        optional :resolve_signal_external_workflow, :message, 12, "coresdk.workflow_activation.ResolveSignalExternalWorkflow"
        optional :resolve_request_cancel_external_workflow, :message, 13, "coresdk.workflow_activation.ResolveRequestCancelExternalWorkflow"
        optional :remove_from_cache, :message, 50, "coresdk.workflow_activation.RemoveFromCache"
      end
    end
    add_message "coresdk.workflow_activation.StartWorkflow" do
      optional :workflow_type, :string, 1
      optional :workflow_id, :string, 2
      repeated :arguments, :message, 3, "temporal.api.common.v1.Payload"
      optional :randomness_seed, :uint64, 4
      map :headers, :string, :message, 5, "temporal.api.common.v1.Payload"
      optional :identity, :string, 6
      optional :parent_workflow_info, :message, 7, "coresdk.common.NamespacedWorkflowExecution"
      optional :workflow_execution_timeout, :message, 8, "google.protobuf.Duration"
      optional :workflow_run_timeout, :message, 9, "google.protobuf.Duration"
      optional :workflow_task_timeout, :message, 10, "google.protobuf.Duration"
      optional :continued_from_execution_run_id, :string, 11
      optional :continued_initiator, :enum, 12, "temporal.api.enums.v1.ContinueAsNewInitiator"
      optional :continued_failure, :message, 13, "temporal.api.failure.v1.Failure"
      optional :last_completion_result, :message, 14, "temporal.api.common.v1.Payloads"
      optional :first_execution_run_id, :string, 15
      optional :retry_policy, :message, 16, "temporal.api.common.v1.RetryPolicy"
      optional :attempt, :int32, 17
      optional :cron_schedule, :string, 18
      optional :workflow_execution_expiration_time, :message, 19, "google.protobuf.Timestamp"
      optional :cron_schedule_to_schedule_interval, :message, 20, "google.protobuf.Duration"
      optional :memo, :message, 21, "temporal.api.common.v1.Memo"
      optional :search_attributes, :message, 22, "temporal.api.common.v1.SearchAttributes"
      optional :start_time, :message, 23, "google.protobuf.Timestamp"
    end
    add_message "coresdk.workflow_activation.FireTimer" do
      optional :seq, :uint32, 1
    end
    add_message "coresdk.workflow_activation.ResolveActivity" do
      optional :seq, :uint32, 1
      optional :result, :message, 2, "coresdk.activity_result.ActivityResolution"
    end
    add_message "coresdk.workflow_activation.ResolveChildWorkflowExecutionStart" do
      optional :seq, :uint32, 1
      oneof :status do
        optional :succeeded, :message, 2, "coresdk.workflow_activation.ResolveChildWorkflowExecutionStartSuccess"
        optional :failed, :message, 3, "coresdk.workflow_activation.ResolveChildWorkflowExecutionStartFailure"
        optional :cancelled, :message, 4, "coresdk.workflow_activation.ResolveChildWorkflowExecutionStartCancelled"
      end
    end
    add_message "coresdk.workflow_activation.ResolveChildWorkflowExecutionStartSuccess" do
      optional :run_id, :string, 1
    end
    add_message "coresdk.workflow_activation.ResolveChildWorkflowExecutionStartFailure" do
      optional :workflow_id, :string, 1
      optional :workflow_type, :string, 2
      optional :cause, :enum, 3, "coresdk.child_workflow.StartChildWorkflowExecutionFailedCause"
    end
    add_message "coresdk.workflow_activation.ResolveChildWorkflowExecutionStartCancelled" do
      optional :failure, :message, 1, "temporal.api.failure.v1.Failure"
    end
    add_message "coresdk.workflow_activation.ResolveChildWorkflowExecution" do
      optional :seq, :uint32, 1
      optional :result, :message, 2, "coresdk.child_workflow.ChildWorkflowResult"
    end
    add_message "coresdk.workflow_activation.UpdateRandomSeed" do
      optional :randomness_seed, :uint64, 1
    end
    add_message "coresdk.workflow_activation.QueryWorkflow" do
      optional :query_id, :string, 1
      optional :query_type, :string, 2
      repeated :arguments, :message, 3, "temporal.api.common.v1.Payload"
      map :headers, :string, :message, 5, "temporal.api.common.v1.Payload"
    end
    add_message "coresdk.workflow_activation.CancelWorkflow" do
      repeated :details, :message, 1, "temporal.api.common.v1.Payload"
    end
    add_message "coresdk.workflow_activation.SignalWorkflow" do
      optional :signal_name, :string, 1
      repeated :input, :message, 2, "temporal.api.common.v1.Payload"
      optional :identity, :string, 3
      map :headers, :string, :message, 5, "temporal.api.common.v1.Payload"
    end
    add_message "coresdk.workflow_activation.NotifyHasPatch" do
      optional :patch_id, :string, 1
    end
    add_message "coresdk.workflow_activation.ResolveSignalExternalWorkflow" do
      optional :seq, :uint32, 1
      optional :failure, :message, 2, "temporal.api.failure.v1.Failure"
    end
    add_message "coresdk.workflow_activation.ResolveRequestCancelExternalWorkflow" do
      optional :seq, :uint32, 1
      optional :failure, :message, 2, "temporal.api.failure.v1.Failure"
    end
    add_message "coresdk.workflow_activation.RemoveFromCache" do
      optional :message, :string, 1
      optional :reason, :enum, 2, "coresdk.workflow_activation.RemoveFromCache.EvictionReason"
    end
    add_enum "coresdk.workflow_activation.RemoveFromCache.EvictionReason" do
      value :UNSPECIFIED, 0
      value :CACHE_FULL, 1
      value :CACHE_MISS, 2
      value :NONDETERMINISM, 3
      value :LANG_FAIL, 4
      value :LANG_REQUESTED, 5
      value :TASK_NOT_FOUND, 6
      value :UNHANDLED_COMMAND, 7
      value :FATAL, 8
    end
  end
end

module Coresdk
  module WorkflowActivation
    WorkflowActivation = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("coresdk.workflow_activation.WorkflowActivation").msgclass
    WorkflowActivationJob = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("coresdk.workflow_activation.WorkflowActivationJob").msgclass
    StartWorkflow = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("coresdk.workflow_activation.StartWorkflow").msgclass
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
    RemoveFromCache = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("coresdk.workflow_activation.RemoveFromCache").msgclass
    RemoveFromCache::EvictionReason = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("coresdk.workflow_activation.RemoveFromCache.EvictionReason").enummodule
  end
end
