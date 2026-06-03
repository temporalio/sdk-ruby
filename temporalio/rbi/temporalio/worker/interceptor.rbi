# typed: true

module Temporalio::Worker::Interceptor; end

module Temporalio::Worker::Interceptor::Activity
  extend T::Sig

  sig { params(next_interceptor: Temporalio::Worker::Interceptor::Activity::Inbound).returns(Temporalio::Worker::Interceptor::Activity::Inbound) }
  def intercept_activity(next_interceptor); end
end

class Temporalio::Worker::Interceptor::Activity::ExecuteInput < ::Data
  extend T::Sig

  sig { returns(Proc) }
  def proc; end

  sig { returns(T::Array[T.nilable(Object)]) }
  def args; end

  sig { returns(T.nilable(Object)) }
  def result_hint; end

  sig { returns(T::Hash[String, T.nilable(Object)]) }
  def headers; end
end

class Temporalio::Worker::Interceptor::Activity::HeartbeatInput < ::Data
  extend T::Sig

  sig { returns(T::Array[T.nilable(Object)]) }
  def details; end

  sig { returns(T.nilable(T::Array[Object])) }
  def detail_hints; end
end

class Temporalio::Worker::Interceptor::Activity::Inbound
  extend T::Sig

  sig { returns(Temporalio::Worker::Interceptor::Activity::Inbound) }
  attr_reader :next_interceptor

  sig { params(next_interceptor: Temporalio::Worker::Interceptor::Activity::Inbound).void }
  def initialize(next_interceptor); end

  sig { params(outbound: Temporalio::Worker::Interceptor::Activity::Outbound).returns(Temporalio::Worker::Interceptor::Activity::Outbound) }
  def init(outbound); end

  sig { params(input: Temporalio::Worker::Interceptor::Activity::ExecuteInput).returns(T.nilable(Object)) }
  def execute(input); end
end

class Temporalio::Worker::Interceptor::Activity::Outbound
  extend T::Sig

  sig { returns(Temporalio::Worker::Interceptor::Activity::Outbound) }
  attr_reader :next_interceptor

  sig { params(next_interceptor: Temporalio::Worker::Interceptor::Activity::Outbound).void }
  def initialize(next_interceptor); end

  sig { params(input: Temporalio::Worker::Interceptor::Activity::HeartbeatInput).void }
  def heartbeat(input); end
end

module Temporalio::Worker::Interceptor::Workflow
  extend T::Sig

  sig { params(next_interceptor: Temporalio::Worker::Interceptor::Workflow::Inbound).returns(Temporalio::Worker::Interceptor::Workflow::Inbound) }
  def intercept_workflow(next_interceptor); end
end

class Temporalio::Worker::Interceptor::Workflow::ExecuteInput < ::Data
  extend T::Sig

  sig { returns(T::Array[T.nilable(Object)]) }
  def args; end

  sig { returns(T::Hash[String, T.nilable(Object)]) }
  def headers; end
end

class Temporalio::Worker::Interceptor::Workflow::HandleSignalInput < ::Data
  extend T::Sig

  sig { returns(String) }
  def signal; end

  sig { returns(T::Array[T.nilable(Object)]) }
  def args; end

  sig { returns(Temporalio::Workflow::Definition::Signal) }
  def definition; end

  sig { returns(T::Hash[String, T.nilable(Object)]) }
  def headers; end
end

class Temporalio::Worker::Interceptor::Workflow::HandleQueryInput < ::Data
  extend T::Sig

  sig { returns(String) }
  def id; end

  sig { returns(String) }
  def query; end

  sig { returns(T::Array[T.nilable(Object)]) }
  def args; end

  sig { returns(Temporalio::Workflow::Definition::Query) }
  def definition; end

  sig { returns(T::Hash[String, T.nilable(Object)]) }
  def headers; end
end

class Temporalio::Worker::Interceptor::Workflow::HandleUpdateInput < ::Data
  extend T::Sig

  sig { returns(String) }
  def id; end

  sig { returns(String) }
  def update; end

  sig { returns(T::Array[T.nilable(Object)]) }
  def args; end

  sig { returns(Temporalio::Workflow::Definition::Update) }
  def definition; end

  sig { returns(T::Hash[String, T.nilable(Object)]) }
  def headers; end
end

class Temporalio::Worker::Interceptor::Workflow::Inbound
  extend T::Sig

  sig { returns(Temporalio::Worker::Interceptor::Workflow::Inbound) }
  attr_reader :next_interceptor

  sig { params(next_interceptor: Temporalio::Worker::Interceptor::Workflow::Inbound).void }
  def initialize(next_interceptor); end

  sig { params(outbound: Temporalio::Worker::Interceptor::Workflow::Outbound).returns(Temporalio::Worker::Interceptor::Workflow::Outbound) }
  def init(outbound); end

  sig { params(input: Temporalio::Worker::Interceptor::Workflow::ExecuteInput).returns(T.nilable(Object)) }
  def execute(input); end

  sig { params(input: Temporalio::Worker::Interceptor::Workflow::HandleSignalInput).void }
  def handle_signal(input); end

  sig { params(input: Temporalio::Worker::Interceptor::Workflow::HandleQueryInput).returns(T.nilable(Object)) }
  def handle_query(input); end

  sig { params(input: Temporalio::Worker::Interceptor::Workflow::HandleUpdateInput).void }
  def validate_update(input); end

  sig { params(input: Temporalio::Worker::Interceptor::Workflow::HandleUpdateInput).returns(T.nilable(Object)) }
  def handle_update(input); end
end

class Temporalio::Worker::Interceptor::Workflow::CancelExternalWorkflowInput < ::Data
  extend T::Sig

  sig { returns(String) }
  def id; end

  sig { returns(T.nilable(String)) }
  def run_id; end
end

class Temporalio::Worker::Interceptor::Workflow::ExecuteActivityInput < ::Data
  extend T::Sig

  sig { returns(String) }
  def activity; end

  sig { returns(T::Array[T.nilable(Object)]) }
  def args; end

  sig { returns(String) }
  def task_queue; end

  sig { returns(T.nilable(String)) }
  def summary; end

  sig { returns(T.nilable(T.any(Integer, Float))) }
  def schedule_to_close_timeout; end

  sig { returns(T.nilable(T.any(Integer, Float))) }
  def schedule_to_start_timeout; end

  sig { returns(T.nilable(T.any(Integer, Float))) }
  def start_to_close_timeout; end

  sig { returns(T.nilable(T.any(Integer, Float))) }
  def heartbeat_timeout; end

  sig { returns(T.nilable(Temporalio::RetryPolicy)) }
  def retry_policy; end

  sig { returns(Temporalio::Cancellation) }
  def cancellation; end

  sig { returns(T.nilable(Integer)) }
  def cancellation_type; end

  sig { returns(T.nilable(String)) }
  def activity_id; end

  sig { returns(T::Boolean) }
  def disable_eager_execution; end

  sig { returns(Temporalio::Priority) }
  def priority; end

  sig { returns(T.nilable(T::Array[Object])) }
  def arg_hints; end

  sig { returns(T.nilable(Object)) }
  def result_hint; end

  sig { returns(T::Hash[String, T.nilable(Object)]) }
  def headers; end
end

class Temporalio::Worker::Interceptor::Workflow::ExecuteLocalActivityInput < ::Data
  extend T::Sig

  sig { returns(String) }
  def activity; end

  sig { returns(T::Array[T.nilable(Object)]) }
  def args; end

  sig { returns(T.nilable(String)) }
  def summary; end

  sig { returns(T.nilable(T.any(Integer, Float))) }
  def schedule_to_close_timeout; end

  sig { returns(T.nilable(T.any(Integer, Float))) }
  def schedule_to_start_timeout; end

  sig { returns(T.nilable(T.any(Integer, Float))) }
  def start_to_close_timeout; end

  sig { returns(T.nilable(Temporalio::RetryPolicy)) }
  def retry_policy; end

  sig { returns(T.nilable(T.any(Integer, Float))) }
  def local_retry_threshold; end

  sig { returns(Temporalio::Cancellation) }
  def cancellation; end

  sig { returns(T.nilable(Integer)) }
  def cancellation_type; end

  sig { returns(T.nilable(String)) }
  def activity_id; end

  sig { returns(T.nilable(T::Array[Object])) }
  def arg_hints; end

  sig { returns(T.nilable(Object)) }
  def result_hint; end

  sig { returns(T::Hash[String, T.nilable(Object)]) }
  def headers; end
end

class Temporalio::Worker::Interceptor::Workflow::InitializeContinueAsNewErrorInput < ::Data
  extend T::Sig

  sig { returns(Temporalio::Workflow::ContinueAsNewError) }
  def error; end
end

class Temporalio::Worker::Interceptor::Workflow::SignalChildWorkflowInput < ::Data
  extend T::Sig

  sig { returns(String) }
  def id; end

  sig { returns(String) }
  def signal; end

  sig { returns(T::Array[T.nilable(Object)]) }
  def args; end

  sig { returns(Temporalio::Cancellation) }
  def cancellation; end

  sig { returns(T.nilable(T::Array[Object])) }
  def arg_hints; end

  sig { returns(T::Hash[String, T.nilable(Object)]) }
  def headers; end
end

class Temporalio::Worker::Interceptor::Workflow::SignalExternalWorkflowInput < ::Data
  extend T::Sig

  sig { returns(String) }
  def id; end

  sig { returns(T.nilable(String)) }
  def run_id; end

  sig { returns(String) }
  def signal; end

  sig { returns(T::Array[T.nilable(Object)]) }
  def args; end

  sig { returns(Temporalio::Cancellation) }
  def cancellation; end

  sig { returns(T.nilable(T::Array[Object])) }
  def arg_hints; end

  sig { returns(T::Hash[String, T.nilable(Object)]) }
  def headers; end
end

class Temporalio::Worker::Interceptor::Workflow::SleepInput < ::Data
  extend T::Sig

  sig { returns(T.nilable(T.any(Integer, Float))) }
  def duration; end

  sig { returns(T.nilable(String)) }
  def summary; end

  sig { returns(Temporalio::Cancellation) }
  def cancellation; end
end

class Temporalio::Worker::Interceptor::Workflow::StartChildWorkflowInput < ::Data
  extend T::Sig

  sig { returns(String) }
  def workflow; end

  sig { returns(T::Array[T.nilable(Object)]) }
  def args; end

  sig { returns(String) }
  def id; end

  sig { returns(String) }
  def task_queue; end

  sig { returns(T.nilable(String)) }
  def static_summary; end

  sig { returns(T.nilable(String)) }
  def static_details; end

  sig { returns(Temporalio::Cancellation) }
  def cancellation; end

  sig { returns(T.nilable(Integer)) }
  def cancellation_type; end

  sig { returns(Integer) }
  def parent_close_policy; end

  sig { returns(T.nilable(T.any(Integer, Float))) }
  def execution_timeout; end

  sig { returns(T.nilable(T.any(Integer, Float))) }
  def run_timeout; end

  sig { returns(T.nilable(T.any(Integer, Float))) }
  def task_timeout; end

  sig { returns(Integer) }
  def id_reuse_policy; end

  sig { returns(T.nilable(Temporalio::RetryPolicy)) }
  def retry_policy; end

  sig { returns(T.nilable(String)) }
  def cron_schedule; end

  sig { returns(T.nilable(T::Hash[T.any(String, Symbol), T.nilable(Object)])) }
  def memo; end

  sig { returns(T.nilable(Temporalio::SearchAttributes)) }
  def search_attributes; end

  sig { returns(Temporalio::Priority) }
  def priority; end

  sig { returns(T.nilable(T::Array[Object])) }
  def arg_hints; end

  sig { returns(T.nilable(Object)) }
  def result_hint; end

  sig { returns(T::Hash[String, T.nilable(Object)]) }
  def headers; end
end

class Temporalio::Worker::Interceptor::Workflow::StartNexusOperationInput < ::Data
  extend T::Sig

  sig { returns(String) }
  def endpoint; end

  sig { returns(String) }
  def service; end

  sig { returns(String) }
  def operation; end

  sig { returns(T.nilable(Object)) }
  def arg; end

  sig { returns(T.nilable(T.any(Integer, Float))) }
  def schedule_to_close_timeout; end

  sig { returns(T.nilable(T.any(Integer, Float))) }
  def schedule_to_start_timeout; end

  sig { returns(T.nilable(T.any(Integer, Float))) }
  def start_to_close_timeout; end

  sig { returns(T.nilable(Integer)) }
  def cancellation_type; end

  sig { returns(T.nilable(String)) }
  def summary; end

  sig { returns(Temporalio::Cancellation) }
  def cancellation; end

  sig { returns(T.nilable(Object)) }
  def arg_hint; end

  sig { returns(T.nilable(Object)) }
  def result_hint; end

  sig { returns(T::Hash[String, String]) }
  def headers; end
end

class Temporalio::Worker::Interceptor::Workflow::Outbound
  extend T::Sig

  sig { returns(Temporalio::Worker::Interceptor::Workflow::Outbound) }
  attr_reader :next_interceptor

  sig { params(next_interceptor: Temporalio::Worker::Interceptor::Workflow::Outbound).void }
  def initialize(next_interceptor); end

  sig { params(input: Temporalio::Worker::Interceptor::Workflow::CancelExternalWorkflowInput).void }
  def cancel_external_workflow(input); end

  sig { params(input: Temporalio::Worker::Interceptor::Workflow::ExecuteActivityInput).returns(T.nilable(Object)) }
  def execute_activity(input); end

  sig { params(input: Temporalio::Worker::Interceptor::Workflow::ExecuteLocalActivityInput).returns(T.nilable(Object)) }
  def execute_local_activity(input); end

  sig { params(input: Temporalio::Worker::Interceptor::Workflow::InitializeContinueAsNewErrorInput).void }
  def initialize_continue_as_new_error(input); end

  sig { params(input: Temporalio::Worker::Interceptor::Workflow::SignalChildWorkflowInput).void }
  def signal_child_workflow(input); end

  sig { params(input: Temporalio::Worker::Interceptor::Workflow::SignalExternalWorkflowInput).void }
  def signal_external_workflow(input); end

  sig { params(input: Temporalio::Worker::Interceptor::Workflow::SleepInput).void }
  def sleep(input); end

  sig { params(input: Temporalio::Worker::Interceptor::Workflow::StartChildWorkflowInput).returns(Temporalio::Workflow::ChildWorkflowHandle) }
  def start_child_workflow(input); end

  sig { params(input: Temporalio::Worker::Interceptor::Workflow::StartNexusOperationInput).returns(Temporalio::Workflow::NexusOperationHandle) }
  def start_nexus_operation(input); end
end
