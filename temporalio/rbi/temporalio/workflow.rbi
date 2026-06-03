# typed: true

module Temporalio::Workflow
  class << self
    extend T::Sig

    sig { returns(T::Boolean) }
    def all_handlers_finished?; end

    sig { returns(Temporalio::Cancellation) }
    def cancellation; end

    sig { returns(T::Boolean) }
    def continue_as_new_suggested; end

    sig { params(endpoint: T.any(Symbol, String), service: T.any(Symbol, String)).returns(Temporalio::Workflow::NexusClient) }
    def create_nexus_client(endpoint:, service:); end

    sig { returns(T::Array[Integer]) }
    def suggest_continue_as_new_reasons; end

    sig { returns(T::Boolean) }
    def target_worker_deployment_version_changed?; end

    sig { returns(String) }
    def current_details; end

    sig { params(details: T.nilable(String)).void }
    def current_details=(details); end

    sig { returns(Integer) }
    def current_history_length; end

    sig { returns(T.nilable(Temporalio::WorkerDeploymentVersion)) }
    def current_deployment_version; end

    sig { returns(Integer) }
    def current_history_size; end

    sig { returns(T.nilable(Temporalio::Workflow::UpdateInfo)) }
    def current_update_info; end

    sig { params(patch_id: T.any(Symbol, String)).void }
    def deprecate_patch(patch_id); end

    sig do
      params(
        activity: T.any(T.class_of(Temporalio::Activity::Definition), Symbol, String),
        args: T.nilable(Object),
        task_queue: String,
        summary: T.nilable(String),
        schedule_to_close_timeout: T.nilable(T.any(Integer, Float)),
        schedule_to_start_timeout: T.nilable(T.any(Integer, Float)),
        start_to_close_timeout: T.nilable(T.any(Integer, Float)),
        heartbeat_timeout: T.nilable(T.any(Integer, Float)),
        retry_policy: T.nilable(Temporalio::RetryPolicy),
        cancellation: Temporalio::Cancellation,
        cancellation_type: Integer,
        activity_id: T.nilable(String),
        disable_eager_execution: T::Boolean,
        priority: Temporalio::Priority,
        arg_hints: T.nilable(T::Array[Object]),
        result_hint: T.nilable(Object)
      ).returns(T.nilable(Object))
    end
    def execute_activity(
      activity,
      *args,
      task_queue: T.unsafe(nil),
      summary: T.unsafe(nil),
      schedule_to_close_timeout: T.unsafe(nil),
      schedule_to_start_timeout: T.unsafe(nil),
      start_to_close_timeout: T.unsafe(nil),
      heartbeat_timeout: T.unsafe(nil),
      retry_policy: T.unsafe(nil),
      cancellation: T.unsafe(nil),
      cancellation_type: T.unsafe(nil),
      activity_id: T.unsafe(nil),
      disable_eager_execution: T.unsafe(nil),
      priority: T.unsafe(nil),
      arg_hints: T.unsafe(nil),
      result_hint: T.unsafe(nil)
    ); end

    sig do
      params(
        workflow: T.any(T.class_of(Temporalio::Workflow::Definition), Temporalio::Workflow::Definition::Info, Symbol, String),
        args: T.nilable(Object),
        id: String,
        task_queue: String,
        static_summary: T.nilable(String),
        static_details: T.nilable(String),
        cancellation: Temporalio::Cancellation,
        cancellation_type: Integer,
        parent_close_policy: Integer,
        execution_timeout: T.nilable(T.any(Integer, Float)),
        run_timeout: T.nilable(T.any(Integer, Float)),
        task_timeout: T.nilable(T.any(Integer, Float)),
        id_reuse_policy: Integer,
        retry_policy: T.nilable(Temporalio::RetryPolicy),
        cron_schedule: T.nilable(String),
        memo: T.nilable(T::Hash[T.any(String, Symbol), T.nilable(Object)]),
        search_attributes: T.nilable(Temporalio::SearchAttributes),
        priority: Temporalio::Priority,
        arg_hints: T.nilable(T::Array[Object]),
        result_hint: T.nilable(Object)
      ).returns(T.nilable(Object))
    end
    def execute_child_workflow(
      workflow,
      *args,
      id: T.unsafe(nil),
      task_queue: T.unsafe(nil),
      static_summary: T.unsafe(nil),
      static_details: T.unsafe(nil),
      cancellation: T.unsafe(nil),
      cancellation_type: T.unsafe(nil),
      parent_close_policy: T.unsafe(nil),
      execution_timeout: T.unsafe(nil),
      run_timeout: T.unsafe(nil),
      task_timeout: T.unsafe(nil),
      id_reuse_policy: T.unsafe(nil),
      retry_policy: T.unsafe(nil),
      cron_schedule: T.unsafe(nil),
      memo: T.unsafe(nil),
      search_attributes: T.unsafe(nil),
      priority: T.unsafe(nil),
      arg_hints: T.unsafe(nil),
      result_hint: T.unsafe(nil)
    ); end

    sig do
      params(
        activity: T.any(T.class_of(Temporalio::Activity::Definition), Symbol, String),
        args: T.nilable(Object),
        summary: T.nilable(String),
        schedule_to_close_timeout: T.nilable(T.any(Integer, Float)),
        schedule_to_start_timeout: T.nilable(T.any(Integer, Float)),
        start_to_close_timeout: T.nilable(T.any(Integer, Float)),
        retry_policy: T.nilable(Temporalio::RetryPolicy),
        local_retry_threshold: T.nilable(T.any(Integer, Float)),
        cancellation: Temporalio::Cancellation,
        cancellation_type: Integer,
        activity_id: T.nilable(String),
        arg_hints: T.nilable(T::Array[Object]),
        result_hint: T.nilable(Object)
      ).returns(T.nilable(Object))
    end
    def execute_local_activity(
      activity,
      *args,
      summary: T.unsafe(nil),
      schedule_to_close_timeout: T.unsafe(nil),
      schedule_to_start_timeout: T.unsafe(nil),
      start_to_close_timeout: T.unsafe(nil),
      retry_policy: T.unsafe(nil),
      local_retry_threshold: T.unsafe(nil),
      cancellation: T.unsafe(nil),
      cancellation_type: T.unsafe(nil),
      activity_id: T.unsafe(nil),
      arg_hints: T.unsafe(nil),
      result_hint: T.unsafe(nil)
    ); end

    sig { params(workflow_id: String, run_id: T.nilable(String)).returns(Temporalio::Workflow::ExternalWorkflowHandle) }
    def external_workflow_handle(workflow_id, run_id: T.unsafe(nil)); end

    sig { returns(T::Boolean) }
    def in_workflow?; end

    sig { returns(Temporalio::Workflow::Info) }
    def info; end

    sig { returns(T.nilable(Temporalio::Workflow::Definition)) }
    def instance; end

    sig { returns(Temporalio::ScopedLogger) }
    def logger; end

    sig { returns(T::Hash[String, T.nilable(Object)]) }
    def memo; end

    sig { returns(Temporalio::Metric::Meter) }
    def metric_meter; end

    sig { returns(Time) }
    def now; end

    sig { params(patch_id: T.any(Symbol, String)).returns(T::Boolean) }
    def patched(patch_id); end

    sig { returns(Temporalio::Converters::PayloadConverter) }
    def payload_converter; end

    sig { returns(T::Hash[T.nilable(String), Temporalio::Workflow::Definition::Query]) }
    def query_handlers; end

    sig { returns(Random) }
    def random; end

    sig { returns(Temporalio::SearchAttributes) }
    def search_attributes; end

    sig { returns(T::Hash[T.nilable(String), Temporalio::Workflow::Definition::Signal]) }
    def signal_handlers; end

    sig { params(duration: T.nilable(T.any(Integer, Float)), summary: T.nilable(String), cancellation: Temporalio::Cancellation).void }
    def sleep(duration, summary: T.unsafe(nil), cancellation: T.unsafe(nil)); end

    sig do
      params(
        workflow: T.any(T.class_of(Temporalio::Workflow::Definition), Temporalio::Workflow::Definition::Info, Symbol, String),
        args: T.nilable(Object),
        id: String,
        task_queue: String,
        static_summary: T.nilable(String),
        static_details: T.nilable(String),
        cancellation: Temporalio::Cancellation,
        cancellation_type: Integer,
        parent_close_policy: Integer,
        execution_timeout: T.nilable(T.any(Integer, Float)),
        run_timeout: T.nilable(T.any(Integer, Float)),
        task_timeout: T.nilable(T.any(Integer, Float)),
        id_reuse_policy: Integer,
        retry_policy: T.nilable(Temporalio::RetryPolicy),
        cron_schedule: T.nilable(String),
        memo: T.nilable(T::Hash[T.any(String, Symbol), T.nilable(Object)]),
        search_attributes: T.nilable(Temporalio::SearchAttributes),
        priority: Temporalio::Priority,
        arg_hints: T.nilable(T::Array[Object]),
        result_hint: T.nilable(Object)
      ).returns(Temporalio::Workflow::ChildWorkflowHandle)
    end
    def start_child_workflow(
      workflow,
      *args,
      id: T.unsafe(nil),
      task_queue: T.unsafe(nil),
      static_summary: T.unsafe(nil),
      static_details: T.unsafe(nil),
      cancellation: T.unsafe(nil),
      cancellation_type: T.unsafe(nil),
      parent_close_policy: T.unsafe(nil),
      execution_timeout: T.unsafe(nil),
      run_timeout: T.unsafe(nil),
      task_timeout: T.unsafe(nil),
      id_reuse_policy: T.unsafe(nil),
      retry_policy: T.unsafe(nil),
      cron_schedule: T.unsafe(nil),
      memo: T.unsafe(nil),
      search_attributes: T.unsafe(nil),
      priority: T.unsafe(nil),
      arg_hints: T.unsafe(nil),
      result_hint: T.unsafe(nil)
    ); end

    sig { returns(T::Hash[Object, Object]) }
    def storage; end

    sig do
      type_parameters(:T)
        .params(
          duration: T.nilable(T.any(Integer, Float)),
          exception_class: T.class_of(Exception),
          message: String,
          summary: T.nilable(String),
          block: T.proc.returns(T.type_parameter(:T))
        ).returns(T.type_parameter(:T))
    end
    def timeout(duration, exception_class = T.unsafe(nil), message = T.unsafe(nil), summary: T.unsafe(nil), &block); end

    sig { returns(T::Hash[T.nilable(String), Temporalio::Workflow::Definition::Update]) }
    def update_handlers; end

    sig { params(hash: T::Hash[T.any(Symbol, String), T.nilable(Object)]).void }
    def upsert_memo(hash); end

    sig { params(updates: Temporalio::SearchAttributes::Update).void }
    def upsert_search_attributes(*updates); end

    sig do
      type_parameters(:T)
        .params(
          cancellation: T.nilable(Temporalio::Cancellation),
          block: T.proc.returns(T.type_parameter(:T))
        ).returns(T.type_parameter(:T))
    end
    def wait_condition(cancellation: T.unsafe(nil), &block); end
  end
end

module Temporalio::Workflow::Unsafe
  class << self
    extend T::Sig

    sig { returns(T::Boolean) }
    def replaying?; end

    sig { returns(T::Boolean) }
    def replaying_history_events?; end

    sig { type_parameters(:T).params(block: T.proc.returns(T.type_parameter(:T))).returns(T.type_parameter(:T)) }
    def illegal_call_tracing_disabled(&block); end

    sig { type_parameters(:T).params(block: T.proc.returns(T.type_parameter(:T))).returns(T.type_parameter(:T)) }
    def io_enabled(&block); end

    sig { type_parameters(:T).params(block: T.proc.returns(T.type_parameter(:T))).returns(T.type_parameter(:T)) }
    def durable_scheduler_disabled(&block); end
  end
end

class Temporalio::Workflow::ContinueAsNewError < ::Temporalio::Error
  extend T::Sig

  sig do
    params(
      args: T.nilable(Object),
      workflow: T.nilable(T.any(T.class_of(Temporalio::Workflow::Definition), String, Symbol)),
      task_queue: T.nilable(String),
      run_timeout: T.nilable(T.any(Integer, Float)),
      task_timeout: T.nilable(T.any(Integer, Float)),
      retry_policy: T.nilable(Temporalio::RetryPolicy),
      memo: T.nilable(T::Hash[T.any(String, Symbol), T.nilable(Object)]),
      search_attributes: T.nilable(Temporalio::SearchAttributes),
      arg_hints: T.nilable(T::Array[Object]),
      headers: T::Hash[String, T.nilable(Object)],
      initial_versioning_behavior: T.nilable(Integer)
    ).void
  end
  def initialize(
    *args,
    workflow: T.unsafe(nil),
    task_queue: T.unsafe(nil),
    run_timeout: T.unsafe(nil),
    task_timeout: T.unsafe(nil),
    retry_policy: T.unsafe(nil),
    memo: T.unsafe(nil),
    search_attributes: T.unsafe(nil),
    arg_hints: T.unsafe(nil),
    headers: T.unsafe(nil),
    initial_versioning_behavior: T.unsafe(nil)
  ); end

  sig { returns(T::Array[T.nilable(Object)]) }
  attr_accessor :args

  sig { returns(T.nilable(T.any(T.class_of(Temporalio::Workflow::Definition), String, Symbol))) }
  attr_accessor :workflow

  sig { returns(T.nilable(String)) }
  attr_accessor :task_queue

  sig { returns(T.nilable(T.any(Integer, Float))) }
  attr_accessor :run_timeout

  sig { returns(T.nilable(T.any(Integer, Float))) }
  attr_accessor :task_timeout

  sig { returns(T.nilable(Temporalio::RetryPolicy)) }
  attr_accessor :retry_policy

  sig { returns(T.nilable(T::Hash[T.any(String, Symbol), T.nilable(Object)])) }
  attr_accessor :memo

  sig { returns(T.nilable(Temporalio::SearchAttributes)) }
  attr_accessor :search_attributes

  sig { returns(T.nilable(T::Array[Object])) }
  attr_accessor :arg_hints

  sig { returns(T::Hash[String, T.nilable(Object)]) }
  attr_accessor :headers

  sig { returns(T.nilable(Integer)) }
  attr_accessor :initial_versioning_behavior

end

class Temporalio::Workflow::InvalidWorkflowStateError < ::Temporalio::Error; end

class Temporalio::Workflow::NondeterminismError < ::Temporalio::Error; end

class Temporalio::Workflow::Mutex < ::Mutex; end

class Temporalio::Workflow::Queue < ::Queue; end

class Temporalio::Workflow::SizedQueue < ::SizedQueue; end
