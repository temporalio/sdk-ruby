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
  attr_reader :context

  sig { returns(Temporalio::Internal::Worker::WorkflowInstance::ReplaySafeLogger) }
  attr_reader :logger

  sig { returns(Temporalio::Workflow::Info) }
  attr_reader :info

  sig { returns(Temporalio::Internal::Worker::WorkflowInstance::Scheduler) }
  attr_reader :scheduler

  sig { returns(T::Boolean) }
  attr_reader :disable_eager_activity_execution

  sig { returns(T::Hash[Integer, Fiber]) }
  attr_reader :pending_activities

  sig { returns(T::Hash[Integer, Fiber]) }
  attr_reader :pending_timers

  sig { returns(T::Hash[Integer, Fiber]) }
  attr_reader :pending_child_workflow_starts

  sig { returns(T::Hash[Integer, Temporalio::Internal::Worker::WorkflowInstance::ChildWorkflowHandle]) }
  attr_reader :pending_child_workflows

  sig { returns(T::Hash[Integer, Fiber]) }
  attr_reader :pending_nexus_operation_starts

  sig { returns(T::Hash[Integer, Temporalio::Internal::Worker::WorkflowInstance::NexusOperationHandle]) }
  attr_reader :pending_nexus_operations

  sig { returns(T::Hash[Integer, Fiber]) }
  attr_reader :pending_external_signals

  sig { returns(T::Hash[Integer, Fiber]) }
  attr_reader :pending_external_cancels

  sig { returns(T::Array[Temporalio::Internal::Worker::WorkflowInstance::HandlerExecution]) }
  attr_reader :in_progress_handlers

  sig { returns(Temporalio::Converters::PayloadConverter) }
  attr_reader :payload_converter

  sig { returns(Temporalio::Converters::FailureConverter) }
  attr_reader :failure_converter

  sig { returns(Temporalio::Cancellation) }
  attr_reader :cancellation

  sig { returns(T::Boolean) }
  attr_reader :continue_as_new_suggested

  sig { returns(T::Array[Integer]) }
  attr_reader :suggest_continue_as_new_reasons

  sig { returns(T::Boolean) }
  attr_reader :target_worker_deployment_version_changed

  sig { returns(T.nilable(Temporalio::WorkerDeploymentVersion)) }
  attr_reader :current_deployment_version

  sig { returns(Integer) }
  attr_reader :current_history_length

  sig { returns(Integer) }
  attr_reader :current_history_size

  sig { returns(T::Boolean) }
  attr_reader :replaying

  sig { returns(Random) }
  attr_reader :random

  sig { returns(T::Hash[T.nilable(String), Temporalio::Workflow::Definition::Signal]) }
  attr_reader :signal_handlers

  sig { returns(T::Hash[T.nilable(String), Temporalio::Workflow::Definition::Query]) }
  attr_reader :query_handlers

  sig { returns(T::Hash[T.nilable(String), Temporalio::Workflow::Definition::Update]) }
  attr_reader :update_handlers

  sig { returns(T::Boolean) }
  attr_reader :context_frozen

  sig { returns(T.proc.params(arg0: String).void) }
  attr_reader :assert_valid_local_activity

  sig { returns(T::Boolean) }
  attr_reader :in_query_or_validator

  sig { returns(T::Boolean) }
  attr_reader :random_disabled

  sig { returns(T.nilable(T.proc.params(input: Temporalio::Worker::PatchActivationInput).returns(T::Boolean))) }
  attr_reader :patch_activation_callback

  sig { returns(T::Boolean) }
  attr_accessor :io_enabled

  sig { returns(T.nilable(String)) }
  attr_accessor :current_details

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

  sig { params(patch_id: String).returns(T::Boolean) }
  def patch_activated?(patch_id); end

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
      .params(
        in_query_or_validator: T::Boolean,
        random_disabled: T::Boolean,
        block: T.proc.returns(T.type_parameter(:T))
      )
      .returns(T.type_parameter(:T))
  end
  def with_context_frozen(in_query_or_validator:, random_disabled: T.unsafe(nil), &block); end

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
