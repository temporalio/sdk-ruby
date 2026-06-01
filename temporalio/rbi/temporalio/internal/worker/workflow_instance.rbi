# typed: true

class Temporalio::Internal::Worker::WorkflowInstance
  extend T::Sig

  sig do
    params(
      run_id: String,
      error: Exception,
      failure_converter: Temporalio::Converters::FailureConverter,
      payload_converter: Temporalio::Converters::PayloadConverter
    ).returns(Object)
  end
  def self.new_completion_with_failure(run_id:, error:, failure_converter:, payload_converter:); end

  sig { returns(Temporalio::Internal::Worker::WorkflowInstance::Context) }
  def context; end

  sig { returns(Temporalio::Internal::Worker::WorkflowInstance::ReplaySafeLogger) }
  def logger; end

  sig { returns(Temporalio::Workflow::Info) }
  def info; end

  sig { returns(Temporalio::Internal::Worker::WorkflowInstance::Scheduler) }
  def scheduler; end

  sig { returns(T::Boolean) }
  def disable_eager_activity_execution; end

  sig { returns(T::Hash[Integer, Fiber]) }
  def pending_activities; end

  sig { returns(T::Hash[Integer, Fiber]) }
  def pending_timers; end

  sig { returns(T::Hash[Integer, Fiber]) }
  def pending_child_workflow_starts; end

  sig { returns(T::Hash[Integer, Temporalio::Internal::Worker::WorkflowInstance::ChildWorkflowHandle]) }
  def pending_child_workflows; end

  sig { returns(T::Hash[Integer, Fiber]) }
  def pending_nexus_operation_starts; end

  sig { returns(T::Hash[Integer, Temporalio::Internal::Worker::WorkflowInstance::NexusOperationHandle]) }
  def pending_nexus_operations; end

  sig { returns(T::Hash[Integer, Fiber]) }
  def pending_external_signals; end

  sig { returns(T::Hash[Integer, Fiber]) }
  def pending_external_cancels; end

  sig { returns(T::Array[Temporalio::Internal::Worker::WorkflowInstance::HandlerExecution]) }
  def in_progress_handlers; end

  sig { returns(Temporalio::Converters::PayloadConverter) }
  def payload_converter; end

  sig { returns(Temporalio::Converters::FailureConverter) }
  def failure_converter; end

  sig { returns(Temporalio::Cancellation) }
  def cancellation; end

  sig { returns(T::Boolean) }
  def continue_as_new_suggested; end

  sig { returns(T::Array[Integer]) }
  def suggest_continue_as_new_reasons; end

  sig { returns(T::Boolean) }
  def target_worker_deployment_version_changed; end

  sig { returns(T.nilable(Temporalio::WorkerDeploymentVersion)) }
  def current_deployment_version; end

  sig { returns(Integer) }
  def current_history_length; end

  sig { returns(Integer) }
  def current_history_size; end

  sig { returns(T::Boolean) }
  def replaying; end

  sig { returns(Random) }
  def random; end

  sig { returns(T::Hash[T.nilable(String), Temporalio::Workflow::Definition::Signal]) }
  def signal_handlers; end

  sig { returns(T::Hash[T.nilable(String), Temporalio::Workflow::Definition::Query]) }
  def query_handlers; end

  sig { returns(T::Hash[T.nilable(String), Temporalio::Workflow::Definition::Update]) }
  def update_handlers; end

  sig { returns(T::Boolean) }
  def context_frozen; end

  sig { returns(T.proc.params(arg0: String).void) }
  def assert_valid_local_activity; end

  sig { returns(T::Boolean) }
  def in_query_or_validator; end

  sig { returns(T::Boolean) }
  def io_enabled; end

  sig { params(io_enabled: T::Boolean).returns(T::Boolean) }
  def io_enabled=(io_enabled); end

  sig { returns(T.nilable(String)) }
  def current_details; end

  sig { params(current_details: T.nilable(String)).returns(T.nilable(String)) }
  def current_details=(current_details); end

  sig { params(details: Temporalio::Internal::Worker::WorkflowInstance::Details).void }
  def initialize(details); end

  sig { params(activation: Object).returns(Object) }
  def activate(activation); end

  sig { params(command: Object).void }
  def add_command(command); end

  sig { returns(Temporalio::Workflow::Definition) }
  def instance; end

  sig { returns(Temporalio::SearchAttributes) }
  def search_attributes; end

  sig { returns(Temporalio::Internal::Worker::WorkflowInstance::ExternallyImmutableHash) }
  def memo; end

  sig { returns(Time) }
  def now; end

  sig { type_parameters(:T).params(block: T.proc.returns(T.type_parameter(:T))).returns(T.type_parameter(:T)) }
  def illegal_call_tracing_disabled(&block); end

  sig { params(patch_id: T.any(Symbol, String), deprecated: T::Boolean).returns(T::Boolean) }
  def patch(patch_id:, deprecated:); end

  sig { returns(Temporalio::Metric::Meter) }
  def metric_meter; end

  private

  sig { returns(Temporalio::Workflow::Definition) }
  def create_instance; end

  sig { params(job: Object).void }
  def apply(job); end

  sig { params(job: Object).void }
  def apply_signal(job); end

  sig { params(job: Object).void }
  def apply_query(job); end

  sig { params(job: Object).void }
  def apply_update(job); end

  sig { void }
  def run_workflow; end

  sig do
    params(
      top_level: T::Boolean,
      handler_exec: T.nilable(Temporalio::Internal::Worker::WorkflowInstance::HandlerExecution),
      block: T.proc.returns(Object)
    ).returns(Fiber)
  end
  def schedule(top_level: T.unsafe(nil), handler_exec: T.unsafe(nil), &block); end

  sig { params(err: Exception).void }
  def on_top_level_exception(err); end

  sig { params(err: Exception).returns(T::Boolean) }
  def failure_exception?(err); end

  sig do
    type_parameters(:T)
      .params(in_query_or_validator: T::Boolean, block: T.proc.returns(T.type_parameter(:T)))
      .returns(T.type_parameter(:T))
  end
  def with_context_frozen(in_query_or_validator:, &block); end

  sig do
    params(
      payload_array: Object,
      defn: T.any(
        Temporalio::Workflow::Definition::Signal,
        Temporalio::Workflow::Definition::Query,
        Temporalio::Workflow::Definition::Update
      )
    ).returns(T::Array[T.nilable(Object)])
  end
  def convert_handler_args(payload_array:, defn:); end

  sig do
    params(
      payload_array: Object,
      method_name: T.nilable(Symbol),
      raw_args: T::Boolean,
      arg_hints: T.nilable(T::Array[Object]),
      ignore_first_param: T::Boolean
    ).returns(T::Array[T.nilable(Object)])
  end
  def convert_args(payload_array:, method_name:, raw_args:, arg_hints:, ignore_first_param: T.unsafe(nil)); end

  sig { returns(Object) }
  def workflow_metadata; end

  sig { returns(T::Hash[Symbol, T.nilable(Object)]) }
  def scoped_logger_info; end

  sig { void }
  def warn_on_any_unfinished_handlers; end
end
