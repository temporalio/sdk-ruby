# typed: true

class Temporalio::Internal::Worker::WorkflowInstance::Context
  extend T::Sig

  sig { params(instance: Temporalio::Internal::Worker::WorkflowInstance).void }
  def initialize(instance); end

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

  sig { returns(Integer) }
  def current_history_size; end

  sig { returns(T.nilable(Temporalio::WorkerDeploymentVersion)) }
  def current_deployment_version; end

  sig { returns(T.nilable(Temporalio::Workflow::UpdateInfo)) }
  def current_update_info; end

  sig { params(patch_id: T.any(Symbol, String)).void }
  def deprecate_patch(patch_id); end

  sig { type_parameters(:T).params(block: T.proc.returns(T.type_parameter(:T))).returns(T.type_parameter(:T)) }
  def durable_scheduler_disabled(&block); end

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
    task_queue:,
    summary:,
    schedule_to_close_timeout:,
    schedule_to_start_timeout:,
    start_to_close_timeout:,
    heartbeat_timeout:,
    retry_policy:,
    cancellation:,
    cancellation_type:,
    activity_id:,
    disable_eager_execution:,
    priority:,
    arg_hints:,
    result_hint:
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
    summary:,
    schedule_to_close_timeout:,
    schedule_to_start_timeout:,
    start_to_close_timeout:,
    retry_policy:,
    local_retry_threshold:,
    cancellation:,
    cancellation_type:,
    activity_id:,
    arg_hints:,
    result_hint:
  ); end

  sig do
    params(workflow_id: String, run_id: T.nilable(String))
      .returns(Temporalio::Internal::Worker::WorkflowInstance::ExternalWorkflowHandle)
  end
  def external_workflow_handle(workflow_id, run_id: T.unsafe(nil)); end

  sig { type_parameters(:T).params(block: T.proc.returns(T.type_parameter(:T))).returns(T.type_parameter(:T)) }
  def illegal_call_tracing_disabled(&block); end

  sig { returns(Temporalio::Workflow::Info) }
  def info; end

  sig { returns(Temporalio::Workflow::Definition) }
  def instance; end

  sig { params(error: Temporalio::Workflow::ContinueAsNewError).void }
  def initialize_continue_as_new_error(error); end

  sig { type_parameters(:T).params(block: T.proc.returns(T.type_parameter(:T))).returns(T.type_parameter(:T)) }
  def io_enabled(&block); end

  sig { returns(Temporalio::Internal::Worker::WorkflowInstance::ReplaySafeLogger) }
  def logger; end

  sig { returns(Temporalio::Internal::Worker::WorkflowInstance::ExternallyImmutableHash) }
  def memo; end

  sig { returns(Temporalio::Metric::Meter) }
  def metric_meter; end

  sig { returns(Time) }
  def now; end

  sig { params(patch_id: T.any(Symbol, String)).returns(T::Boolean) }
  def patched(patch_id); end

  sig { returns(Temporalio::Converters::PayloadConverter) }
  def payload_converter; end

  sig { returns(Temporalio::Internal::Worker::WorkflowInstance::HandlerHash) }
  def query_handlers; end

  sig { returns(Random) }
  def random; end

  sig { returns(T::Boolean) }
  def replaying?; end

  sig { returns(T::Boolean) }
  def replaying_history_events?; end

  sig { returns(Temporalio::SearchAttributes) }
  def search_attributes; end

  sig { returns(Temporalio::Internal::Worker::WorkflowInstance::HandlerHash) }
  def signal_handlers; end

  sig { params(duration: T.nilable(T.any(Integer, Float)), summary: T.nilable(String), cancellation: Temporalio::Cancellation).void }
  def sleep(duration, summary:, cancellation:); end

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
    ).returns(Temporalio::Internal::Worker::WorkflowInstance::ChildWorkflowHandle)
  end
  def start_child_workflow(
    workflow,
    *args,
    id:,
    task_queue:,
    static_summary:,
    static_details:,
    cancellation:,
    cancellation_type:,
    parent_close_policy:,
    execution_timeout:,
    run_timeout:,
    task_timeout:,
    id_reuse_policy:,
    retry_policy:,
    cron_schedule:,
    memo:,
    search_attributes:,
    priority:,
    arg_hints:,
    result_hint:
  ); end

  sig { returns(T::Hash[Object, Object]) }
  def storage; end

  sig do
    type_parameters(:T)
      .params(
        duration: T.nilable(T.any(Integer, Float)),
        exception_class: T.class_of(Exception),
        exception_args: T.nilable(Object),
        summary: T.nilable(String),
        block: T.proc.returns(T.type_parameter(:T))
      )
      .returns(T.type_parameter(:T))
  end
  def timeout(duration, exception_class, *exception_args, summary:, &block); end

  sig { returns(Temporalio::Internal::Worker::WorkflowInstance::HandlerHash) }
  def update_handlers; end

  sig { params(hash: T::Hash[T.any(Symbol, String), T.nilable(Object)]).void }
  def upsert_memo(hash); end

  sig { params(updates: Temporalio::SearchAttributes::Update).void }
  def upsert_search_attributes(*updates); end

  sig do
    type_parameters(:T)
      .params(cancellation: T.nilable(Temporalio::Cancellation), block: T.proc.returns(T.type_parameter(:T)))
      .returns(T.type_parameter(:T))
  end
  def wait_condition(cancellation:, &block); end

  sig { params(id: String, run_id: T.nilable(String)).void }
  def _cancel_external_workflow(id:, run_id:); end

  sig { params(outbound: Temporalio::Worker::Interceptor::Workflow::Outbound).void }
  def _outbound=(outbound); end

  sig do
    params(
      id: String,
      signal: T.any(Temporalio::Workflow::Definition::Signal, Symbol, String),
      args: T::Array[T.nilable(Object)],
      cancellation: Temporalio::Cancellation,
      arg_hints: T.nilable(T::Array[Object])
    ).void
  end
  def _signal_child_workflow(id:, signal:, args:, cancellation:, arg_hints:); end

  sig do
    params(
      id: String,
      run_id: T.nilable(String),
      signal: T.any(Temporalio::Workflow::Definition::Signal, Symbol, String),
      args: T::Array[T.nilable(Object)],
      cancellation: Temporalio::Cancellation,
      arg_hints: T.nilable(T::Array[Object])
    ).void
  end
  def _signal_external_workflow(id:, run_id:, signal:, args:, cancellation:, arg_hints:); end
end
