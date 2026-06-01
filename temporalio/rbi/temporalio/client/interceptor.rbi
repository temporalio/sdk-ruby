# typed: true

# Sorbet RBI types for the Temporal Ruby SDK.
# This file was split from rbi/temporalio.rbi by extra/split_rbi.rb.

module Temporalio::Client::Interceptor
  sig { params(next_interceptor: Temporalio::Client::Interceptor::Outbound).returns(Temporalio::Client::Interceptor::Outbound) }
  def intercept_client(next_interceptor); end
end

class Temporalio::Client::Interceptor::StartWorkflowInput < ::Data
  sig { returns(String) }
  def workflow; end

  sig { returns(T::Array[T.nilable(Object)]) }
  def args; end

  sig { returns(String) }
  def workflow_id; end

  sig { returns(String) }
  def task_queue; end

  sig { returns(T.nilable(String)) }
  def static_summary; end

  sig { returns(T.nilable(String)) }
  def static_details; end

  sig { returns(T.nilable(T.any(Integer, Float))) }
  def execution_timeout; end

  sig { returns(T.nilable(T.any(Integer, Float))) }
  def run_timeout; end

  sig { returns(T.nilable(T.any(Integer, Float))) }
  def task_timeout; end

  sig { returns(Integer) }
  def id_reuse_policy; end

  sig { returns(Integer) }
  def id_conflict_policy; end

  sig { returns(T.nilable(Temporalio::RetryPolicy)) }
  def retry_policy; end

  sig { returns(T.nilable(String)) }
  def cron_schedule; end

  sig { returns(T.nilable(T::Hash[T.any(String, Symbol), T.nilable(Object)])) }
  def memo; end

  sig { returns(T.nilable(Temporalio::SearchAttributes)) }
  def search_attributes; end

  sig { returns(T.nilable(T.any(Integer, Float))) }
  def start_delay; end

  sig { returns(T::Boolean) }
  def request_eager_start; end

  sig { returns(T.nilable(Temporalio::VersioningOverride)) }
  def versioning_override; end

  sig { returns(Temporalio::Priority) }
  def priority; end

  sig { returns(T.nilable(T::Array[Object])) }
  def arg_hints; end

  sig { returns(T.nilable(Object)) }
  def result_hint; end

  sig { returns(T::Hash[String, T.nilable(Object)]) }
  def headers; end

  sig { returns(T.nilable(Temporalio::Client::RPCOptions)) }
  def rpc_options; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Client::Interceptor::StartWorkflowInput) }
    def new(*args); end

    sig { params(args: T.untyped).returns(Temporalio::Client::Interceptor::StartWorkflowInput) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end

class Temporalio::Client::Interceptor::StartUpdateWithStartWorkflowInput < ::Data
  sig { returns(String) }
  def update_id; end

  sig { returns(String) }
  def update; end

  sig { returns(T::Array[T.nilable(Object)]) }
  def args; end

  sig { returns(Integer) }
  def wait_for_stage; end

  sig { returns(Temporalio::Client::WithStartWorkflowOperation) }
  def start_workflow_operation; end

  sig { returns(T.nilable(T::Array[Object])) }
  def arg_hints; end

  sig { returns(T.nilable(Object)) }
  def result_hint; end

  sig { returns(T::Hash[String, T.nilable(Object)]) }
  def headers; end

  sig { returns(T.nilable(Temporalio::Client::RPCOptions)) }
  def rpc_options; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Client::Interceptor::StartUpdateWithStartWorkflowInput) }
    def new(*args); end

    sig { params(args: T.untyped).returns(Temporalio::Client::Interceptor::StartUpdateWithStartWorkflowInput) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end

class Temporalio::Client::Interceptor::SignalWithStartWorkflowInput < ::Data
  sig { returns(String) }
  def signal; end

  sig { returns(T::Array[T.nilable(Object)]) }
  def args; end

  sig { returns(Temporalio::Client::WithStartWorkflowOperation) }
  def start_workflow_operation; end

  sig { returns(T.nilable(T::Array[Object])) }
  def arg_hints; end

  sig { returns(T.nilable(Temporalio::Client::RPCOptions)) }
  def rpc_options; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Client::Interceptor::SignalWithStartWorkflowInput) }
    def new(*args); end

    sig { params(args: T.untyped).returns(Temporalio::Client::Interceptor::SignalWithStartWorkflowInput) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end

class Temporalio::Client::Interceptor::ListWorkflowPageInput < ::Data
  sig { returns(T.nilable(String)) }
  def query; end

  sig { returns(T.nilable(String)) }
  def next_page_token; end

  sig { returns(T.nilable(Integer)) }
  def page_size; end

  sig { returns(T.nilable(Temporalio::Client::RPCOptions)) }
  def rpc_options; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Client::Interceptor::ListWorkflowPageInput) }
    def new(*args); end

    sig { params(args: T.untyped).returns(Temporalio::Client::Interceptor::ListWorkflowPageInput) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end

class Temporalio::Client::Interceptor::CountWorkflowsInput < ::Data
  sig { returns(T.nilable(String)) }
  def query; end

  sig { returns(T.nilable(Temporalio::Client::RPCOptions)) }
  def rpc_options; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Client::Interceptor::CountWorkflowsInput) }
    def new(*args); end

    sig { params(args: T.untyped).returns(Temporalio::Client::Interceptor::CountWorkflowsInput) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end

class Temporalio::Client::Interceptor::DescribeWorkflowInput < ::Data
  sig { returns(String) }
  def workflow_id; end

  sig { returns(T.nilable(String)) }
  def run_id; end

  sig { returns(T.nilable(Temporalio::Client::RPCOptions)) }
  def rpc_options; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Client::Interceptor::DescribeWorkflowInput) }
    def new(*args); end

    sig { params(args: T.untyped).returns(Temporalio::Client::Interceptor::DescribeWorkflowInput) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end

class Temporalio::Client::Interceptor::FetchWorkflowHistoryEventsInput < ::Data
  sig { returns(String) }
  def workflow_id; end

  sig { returns(T.nilable(String)) }
  def run_id; end

  sig { returns(T::Boolean) }
  def wait_new_event; end

  sig { returns(Integer) }
  def event_filter_type; end

  sig { returns(T::Boolean) }
  def skip_archival; end

  sig { returns(T.nilable(Temporalio::Client::RPCOptions)) }
  def rpc_options; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Client::Interceptor::FetchWorkflowHistoryEventsInput) }
    def new(*args); end

    sig { params(args: T.untyped).returns(Temporalio::Client::Interceptor::FetchWorkflowHistoryEventsInput) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end

class Temporalio::Client::Interceptor::SignalWorkflowInput < ::Data
  sig { returns(String) }
  def workflow_id; end

  sig { returns(T.nilable(String)) }
  def run_id; end

  sig { returns(String) }
  def signal; end

  sig { returns(T::Array[T.nilable(Object)]) }
  def args; end

  sig { returns(T.nilable(T::Array[Object])) }
  def arg_hints; end

  sig { returns(T::Hash[String, T.nilable(Object)]) }
  def headers; end

  sig { returns(T.nilable(Temporalio::Client::RPCOptions)) }
  def rpc_options; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Client::Interceptor::SignalWorkflowInput) }
    def new(*args); end

    sig { params(args: T.untyped).returns(Temporalio::Client::Interceptor::SignalWorkflowInput) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end

class Temporalio::Client::Interceptor::QueryWorkflowInput < ::Data
  sig { returns(String) }
  def workflow_id; end

  sig { returns(T.nilable(String)) }
  def run_id; end

  sig { returns(String) }
  def query; end

  sig { returns(T::Array[T.nilable(Object)]) }
  def args; end

  sig { returns(T.nilable(Integer)) }
  def reject_condition; end

  sig { returns(T.nilable(T::Array[Object])) }
  def arg_hints; end

  sig { returns(T.nilable(Object)) }
  def result_hint; end

  sig { returns(T::Hash[String, T.nilable(Object)]) }
  def headers; end

  sig { returns(T.nilable(Temporalio::Client::RPCOptions)) }
  def rpc_options; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Client::Interceptor::QueryWorkflowInput) }
    def new(*args); end

    sig { params(args: T.untyped).returns(Temporalio::Client::Interceptor::QueryWorkflowInput) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end

class Temporalio::Client::Interceptor::StartWorkflowUpdateInput < ::Data
  sig { returns(String) }
  def workflow_id; end

  sig { returns(T.nilable(String)) }
  def run_id; end

  sig { returns(String) }
  def update_id; end

  sig { returns(String) }
  def update; end

  sig { returns(T::Array[T.nilable(Object)]) }
  def args; end

  sig { returns(Integer) }
  def wait_for_stage; end

  sig { returns(T.nilable(T::Array[Object])) }
  def arg_hints; end

  sig { returns(T.nilable(Object)) }
  def result_hint; end

  sig { returns(T::Hash[String, T.nilable(Object)]) }
  def headers; end

  sig { returns(T.nilable(Temporalio::Client::RPCOptions)) }
  def rpc_options; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Client::Interceptor::StartWorkflowUpdateInput) }
    def new(*args); end

    sig { params(args: T.untyped).returns(Temporalio::Client::Interceptor::StartWorkflowUpdateInput) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end

class Temporalio::Client::Interceptor::PollWorkflowUpdateInput < ::Data
  sig { returns(String) }
  def workflow_id; end

  sig { returns(T.nilable(String)) }
  def run_id; end

  sig { returns(String) }
  def update_id; end

  sig { returns(T.nilable(Temporalio::Client::RPCOptions)) }
  def rpc_options; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Client::Interceptor::PollWorkflowUpdateInput) }
    def new(*args); end

    sig { params(args: T.untyped).returns(Temporalio::Client::Interceptor::PollWorkflowUpdateInput) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end

class Temporalio::Client::Interceptor::CancelWorkflowInput < ::Data
  sig { returns(String) }
  def workflow_id; end

  sig { returns(T.nilable(String)) }
  def run_id; end

  sig { returns(T.nilable(String)) }
  def first_execution_run_id; end

  sig { returns(T.nilable(Temporalio::Client::RPCOptions)) }
  def rpc_options; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Client::Interceptor::CancelWorkflowInput) }
    def new(*args); end

    sig { params(args: T.untyped).returns(Temporalio::Client::Interceptor::CancelWorkflowInput) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end

class Temporalio::Client::Interceptor::TerminateWorkflowInput < ::Data
  sig { returns(String) }
  def workflow_id; end

  sig { returns(T.nilable(String)) }
  def run_id; end

  sig { returns(T.nilable(String)) }
  def first_execution_run_id; end

  sig { returns(T.nilable(String)) }
  def reason; end

  sig { returns(T::Array[T.nilable(Object)]) }
  def details; end

  sig { returns(T.nilable(Temporalio::Client::RPCOptions)) }
  def rpc_options; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Client::Interceptor::TerminateWorkflowInput) }
    def new(*args); end

    sig { params(args: T.untyped).returns(Temporalio::Client::Interceptor::TerminateWorkflowInput) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end

class Temporalio::Client::Interceptor::CreateScheduleInput < ::Data
  sig { returns(String) }
  def id; end

  sig { returns(Temporalio::Client::Schedule) }
  def schedule; end

  sig { returns(T::Boolean) }
  def trigger_immediately; end

  sig { returns(T::Array[Temporalio::Client::Schedule::Backfill]) }
  def backfills; end

  sig { returns(T.nilable(T::Hash[T.any(String, Symbol), T.nilable(Object)])) }
  def memo; end

  sig { returns(T.nilable(Temporalio::SearchAttributes)) }
  def search_attributes; end

  sig { returns(T.nilable(Temporalio::Client::RPCOptions)) }
  def rpc_options; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Client::Interceptor::CreateScheduleInput) }
    def new(*args); end

    sig { params(args: T.untyped).returns(Temporalio::Client::Interceptor::CreateScheduleInput) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end

class Temporalio::Client::Interceptor::ListSchedulesInput < ::Data
  sig { returns(T.nilable(String)) }
  def query; end

  sig { returns(T.nilable(Temporalio::Client::RPCOptions)) }
  def rpc_options; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Client::Interceptor::ListSchedulesInput) }
    def new(*args); end

    sig { params(args: T.untyped).returns(Temporalio::Client::Interceptor::ListSchedulesInput) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end

class Temporalio::Client::Interceptor::BackfillScheduleInput < ::Data
  sig { returns(String) }
  def id; end

  sig { returns(T::Array[Temporalio::Client::Schedule::Backfill]) }
  def backfills; end

  sig { returns(T.nilable(Temporalio::Client::RPCOptions)) }
  def rpc_options; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Client::Interceptor::BackfillScheduleInput) }
    def new(*args); end

    sig { params(args: T.untyped).returns(Temporalio::Client::Interceptor::BackfillScheduleInput) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end

class Temporalio::Client::Interceptor::DeleteScheduleInput < ::Data
  sig { returns(String) }
  def id; end

  sig { returns(T.nilable(Temporalio::Client::RPCOptions)) }
  def rpc_options; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Client::Interceptor::DeleteScheduleInput) }
    def new(*args); end

    sig { params(args: T.untyped).returns(Temporalio::Client::Interceptor::DeleteScheduleInput) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end

class Temporalio::Client::Interceptor::DescribeScheduleInput < ::Data
  sig { returns(String) }
  def id; end

  sig { returns(T.nilable(Temporalio::Client::RPCOptions)) }
  def rpc_options; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Client::Interceptor::DescribeScheduleInput) }
    def new(*args); end

    sig { params(args: T.untyped).returns(Temporalio::Client::Interceptor::DescribeScheduleInput) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end

class Temporalio::Client::Interceptor::PauseScheduleInput < ::Data
  sig { returns(String) }
  def id; end

  sig { returns(String) }
  def note; end

  sig { returns(T.nilable(Temporalio::Client::RPCOptions)) }
  def rpc_options; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Client::Interceptor::PauseScheduleInput) }
    def new(*args); end

    sig { params(args: T.untyped).returns(Temporalio::Client::Interceptor::PauseScheduleInput) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end

class Temporalio::Client::Interceptor::TriggerScheduleInput < ::Data
  sig { returns(String) }
  def id; end

  sig { returns(T.nilable(Integer)) }
  def overlap; end

  sig { returns(T.nilable(Temporalio::Client::RPCOptions)) }
  def rpc_options; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Client::Interceptor::TriggerScheduleInput) }
    def new(*args); end

    sig { params(args: T.untyped).returns(Temporalio::Client::Interceptor::TriggerScheduleInput) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end

class Temporalio::Client::Interceptor::UnpauseScheduleInput < ::Data
  sig { returns(String) }
  def id; end

  sig { returns(String) }
  def note; end

  sig { returns(T.nilable(Temporalio::Client::RPCOptions)) }
  def rpc_options; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Client::Interceptor::UnpauseScheduleInput) }
    def new(*args); end

    sig { params(args: T.untyped).returns(Temporalio::Client::Interceptor::UnpauseScheduleInput) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end

class Temporalio::Client::Interceptor::UpdateScheduleInput < ::Data
  sig { returns(String) }
  def id; end

  sig { returns(T.proc.params(arg0: Temporalio::Client::Schedule::Update::Input).returns(T.nilable(Temporalio::Client::Schedule::Update))) }
  def updater; end

  sig { returns(T.nilable(Temporalio::Client::RPCOptions)) }
  def rpc_options; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Client::Interceptor::UpdateScheduleInput) }
    def new(*args); end

    sig { params(args: T.untyped).returns(Temporalio::Client::Interceptor::UpdateScheduleInput) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end

class Temporalio::Client::Interceptor::HeartbeatAsyncActivityInput < ::Data
  sig { returns(T.any(String, Temporalio::Client::ActivityIDReference)) }
  def task_token_or_id_reference; end

  sig { returns(T::Array[T.nilable(Object)]) }
  def details; end

  sig { returns(T.nilable(T::Array[Object])) }
  def detail_hints; end

  sig { returns(T.nilable(Temporalio::Client::RPCOptions)) }
  def rpc_options; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Client::Interceptor::HeartbeatAsyncActivityInput) }
    def new(*args); end

    sig { params(args: T.untyped).returns(Temporalio::Client::Interceptor::HeartbeatAsyncActivityInput) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end

class Temporalio::Client::Interceptor::CompleteAsyncActivityInput < ::Data
  sig { returns(T.any(String, Temporalio::Client::ActivityIDReference)) }
  def task_token_or_id_reference; end

  sig { returns(T.nilable(Object)) }
  def result; end

  sig { returns(T.nilable(Object)) }
  def result_hint; end

  sig { returns(T.nilable(Temporalio::Client::RPCOptions)) }
  def rpc_options; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Client::Interceptor::CompleteAsyncActivityInput) }
    def new(*args); end

    sig { params(args: T.untyped).returns(Temporalio::Client::Interceptor::CompleteAsyncActivityInput) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end

class Temporalio::Client::Interceptor::FailAsyncActivityInput < ::Data
  sig { returns(T.any(String, Temporalio::Client::ActivityIDReference)) }
  def task_token_or_id_reference; end

  sig { returns(Exception) }
  def error; end

  sig { returns(T::Array[T.nilable(Object)]) }
  def last_heartbeat_details; end

  sig { returns(T.nilable(T::Array[Object])) }
  def last_heartbeat_detail_hints; end

  sig { returns(T.nilable(Temporalio::Client::RPCOptions)) }
  def rpc_options; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Client::Interceptor::FailAsyncActivityInput) }
    def new(*args); end

    sig { params(args: T.untyped).returns(Temporalio::Client::Interceptor::FailAsyncActivityInput) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end

class Temporalio::Client::Interceptor::ReportCancellationAsyncActivityInput < ::Data
  sig { returns(T.any(String, Temporalio::Client::ActivityIDReference)) }
  def task_token_or_id_reference; end

  sig { returns(T::Array[T.nilable(Object)]) }
  def details; end

  sig { returns(T.nilable(T::Array[Object])) }
  def detail_hints; end

  sig { returns(T.nilable(Temporalio::Client::RPCOptions)) }
  def rpc_options; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Client::Interceptor::ReportCancellationAsyncActivityInput) }
    def new(*args); end

    sig { params(args: T.untyped).returns(Temporalio::Client::Interceptor::ReportCancellationAsyncActivityInput) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end

class Temporalio::Client::Interceptor::Outbound
  sig { params(next_interceptor: Temporalio::Client::Interceptor::Outbound).void }
  def initialize(next_interceptor); end

  sig { returns(Temporalio::Client::Interceptor::Outbound) }
  def next_interceptor; end

  sig { params(input: Temporalio::Client::Interceptor::StartWorkflowInput).returns(Temporalio::Client::WorkflowHandle) }
  def start_workflow(input); end

  sig { params(input: Temporalio::Client::Interceptor::StartUpdateWithStartWorkflowInput).returns(Temporalio::Client::WorkflowUpdateHandle) }
  def start_update_with_start_workflow(input); end

  sig { params(input: Temporalio::Client::Interceptor::SignalWithStartWorkflowInput).returns(Temporalio::Client::WorkflowHandle) }
  def signal_with_start_workflow(input); end

  sig { params(input: Temporalio::Client::Interceptor::ListWorkflowPageInput).returns(Temporalio::Client::ListWorkflowPage) }
  def list_workflow_page(input); end

  sig { params(input: Temporalio::Client::Interceptor::CountWorkflowsInput).returns(Temporalio::Client::WorkflowExecutionCount) }
  def count_workflows(input); end

  sig { params(input: Temporalio::Client::Interceptor::DescribeWorkflowInput).returns(Temporalio::Client::WorkflowExecution::Description) }
  def describe_workflow(input); end

  sig { params(input: Temporalio::Client::Interceptor::FetchWorkflowHistoryEventsInput).returns(T::Enumerator[Temporalio::Api::History::V1::HistoryEvent]) }
  def fetch_workflow_history_events(input); end

  sig { params(input: Temporalio::Client::Interceptor::SignalWorkflowInput).void }
  def signal_workflow(input); end

  sig { params(input: Temporalio::Client::Interceptor::QueryWorkflowInput).returns(T.nilable(Object)) }
  def query_workflow(input); end

  sig { params(input: Temporalio::Client::Interceptor::StartWorkflowUpdateInput).returns(Temporalio::Client::WorkflowUpdateHandle) }
  def start_workflow_update(input); end

  sig { params(input: Temporalio::Client::Interceptor::PollWorkflowUpdateInput).returns(Temporalio::Api::Update::V1::Outcome) }
  def poll_workflow_update(input); end

  sig { params(input: Temporalio::Client::Interceptor::CancelWorkflowInput).void }
  def cancel_workflow(input); end

  sig { params(input: Temporalio::Client::Interceptor::TerminateWorkflowInput).void }
  def terminate_workflow(input); end

  sig { params(input: Temporalio::Client::Interceptor::CreateScheduleInput).returns(Temporalio::Client::ScheduleHandle) }
  def create_schedule(input); end

  sig { params(input: Temporalio::Client::Interceptor::ListSchedulesInput).returns(T::Enumerator[Temporalio::Client::WorkflowExecution]) }
  def list_schedules(input); end

  sig { params(input: Temporalio::Client::Interceptor::BackfillScheduleInput).void }
  def backfill_schedule(input); end

  sig { params(input: Temporalio::Client::Interceptor::DeleteScheduleInput).void }
  def delete_schedule(input); end

  sig { params(input: Temporalio::Client::Interceptor::DescribeScheduleInput).returns(Temporalio::Client::Schedule::Description) }
  def describe_schedule(input); end

  sig { params(input: Temporalio::Client::Interceptor::PauseScheduleInput).void }
  def pause_schedule(input); end

  sig { params(input: Temporalio::Client::Interceptor::TriggerScheduleInput).void }
  def trigger_schedule(input); end

  sig { params(input: Temporalio::Client::Interceptor::UnpauseScheduleInput).void }
  def unpause_schedule(input); end

  sig { params(input: Temporalio::Client::Interceptor::UpdateScheduleInput).void }
  def update_schedule(input); end

  sig { params(input: Temporalio::Client::Interceptor::HeartbeatAsyncActivityInput).void }
  def heartbeat_async_activity(input); end

  sig { params(input: Temporalio::Client::Interceptor::CompleteAsyncActivityInput).void }
  def complete_async_activity(input); end

  sig { params(input: Temporalio::Client::Interceptor::FailAsyncActivityInput).void }
  def fail_async_activity(input); end

  sig { params(input: Temporalio::Client::Interceptor::ReportCancellationAsyncActivityInput).void }
  def report_cancellation_async_activity(input); end
end
