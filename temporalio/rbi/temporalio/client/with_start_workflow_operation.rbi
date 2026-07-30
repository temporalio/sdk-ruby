# typed: true

class Temporalio::Client::WithStartWorkflowOperation
  sig do
    params(
      workflow: T.any(T.class_of(Temporalio::Workflow::Definition), Temporalio::Workflow::Definition::Info, Symbol, String),
      args: T.nilable(Object),
      id: String,
      task_queue: String,
      static_summary: T.nilable(String),
      static_details: T.nilable(String),
      execution_timeout: T.nilable(T.any(Integer, Float)),
      run_timeout: T.nilable(T.any(Integer, Float)),
      task_timeout: T.nilable(T.any(Integer, Float)),
      id_reuse_policy: Integer,
      id_conflict_policy: Integer,
      retry_policy: T.nilable(Temporalio::RetryPolicy),
      cron_schedule: T.nilable(String),
      memo: T.nilable(T::Hash[T.any(String, Symbol), T.nilable(Object)]),
      search_attributes: T.nilable(Temporalio::SearchAttributes),
      start_delay: T.nilable(T.any(Integer, Float)),
      priority: Temporalio::Priority,
      arg_hints: T.nilable(T::Array[Object]),
      result_hint: T.nilable(Object),
      headers: T.nilable(T::Hash[String, T.nilable(Object)])
    ).void
  end
  def initialize(
    workflow,
    *args,
    id:,
    task_queue:,
    static_summary: T.unsafe(nil),
    static_details: T.unsafe(nil),
    execution_timeout: T.unsafe(nil),
    run_timeout: T.unsafe(nil),
    task_timeout: T.unsafe(nil),
    id_reuse_policy: T.unsafe(nil),
    id_conflict_policy: T.unsafe(nil),
    retry_policy: T.unsafe(nil),
    cron_schedule: T.unsafe(nil),
    memo: T.unsafe(nil),
    search_attributes: T.unsafe(nil),
    start_delay: T.unsafe(nil),
    priority: T.unsafe(nil),
    arg_hints: T.unsafe(nil),
    result_hint: T.unsafe(nil),
    headers: T.unsafe(nil)
  ); end

  sig { returns(Temporalio::Client::WithStartWorkflowOperation::Options) }
  attr_accessor :options

  sig { params(wait: T::Boolean).returns(T.nilable(Temporalio::Client::WorkflowHandle)) }
  def workflow_handle(wait: T.unsafe(nil)); end
end

class Temporalio::Client::WithStartWorkflowOperation::Options < ::Data
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

  sig { returns(T.nilable(T::Array[Object])) }
  def arg_hints; end

  sig { returns(T.nilable(Object)) }
  def result_hint; end

  sig { returns(T::Hash[String, T.nilable(Object)]) }
  def headers; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Client::WithStartWorkflowOperation::Options) }
    def new(*args); end

    sig { params(args: T.untyped).returns(Temporalio::Client::WithStartWorkflowOperation::Options) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end
