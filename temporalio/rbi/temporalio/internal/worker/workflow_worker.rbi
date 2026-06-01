# typed: true

class Temporalio::Internal::Worker::WorkflowWorker
  extend T::Sig

  sig do
    params(
      workflows: T::Array[T.any(T.class_of(Temporalio::Workflow::Definition), Temporalio::Workflow::Definition::Info)],
      should_enforce_versioning_behavior: T::Boolean
    ).returns(T::Hash[T.nilable(String), Temporalio::Workflow::Definition::Info])
  end
  def self.workflow_definitions(workflows, should_enforce_versioning_behavior:); end

  sig do
    params(
      workflow_failure_exception_types: T::Array[T.class_of(Exception)],
      workflow_definitions: T::Hash[T.nilable(String), Temporalio::Workflow::Definition::Info]
    ).returns([T::Boolean, T::Array[String]])
  end
  def self.bridge_workflow_failure_exception_type_options(workflow_failure_exception_types:, workflow_definitions:); end

  sig do
    params(
      bridge_worker: Temporalio::Internal::Bridge::Worker,
      namespace: String,
      task_queue: String,
      workflow_definitions: T::Hash[T.nilable(String), Temporalio::Workflow::Definition::Info],
      workflow_executor: Temporalio::Worker::WorkflowExecutor,
      logger: Logger,
      data_converter: Temporalio::Converters::DataConverter,
      metric_meter: Temporalio::Metric::Meter,
      workflow_interceptors: T::Array[Temporalio::Worker::Interceptor::Workflow],
      disable_eager_activity_execution: T::Boolean,
      illegal_workflow_calls: T.nilable(T::Hash[String, Object]),
      workflow_failure_exception_types: T::Array[T.class_of(Exception)],
      workflow_payload_codec_thread_pool: T.nilable(Temporalio::Worker::ThreadPool),
      unsafe_workflow_io_enabled: T::Boolean,
      debug_mode: T::Boolean,
      assert_valid_local_activity: T.proc.params(arg0: String).void,
      on_eviction: T.nilable(T.proc.params(arg0: String, arg1: Object).void)
    ).void
  end
  def initialize(
    bridge_worker:,
    namespace:,
    task_queue:,
    workflow_definitions:,
    workflow_executor:,
    logger:,
    data_converter:,
    metric_meter:,
    workflow_interceptors:,
    disable_eager_activity_execution:,
    illegal_workflow_calls:,
    workflow_failure_exception_types:,
    workflow_payload_codec_thread_pool:,
    unsafe_workflow_io_enabled:,
    debug_mode:,
    assert_valid_local_activity:,
    on_eviction: T.unsafe(nil)
  ); end

  sig do
    params(
      runner: Temporalio::Internal::Worker::MultiRunner,
      activation: Object,
      decoded: T::Boolean
    ).void
  end
  def handle_activation(runner:, activation:, decoded:); end

  sig do
    params(
      runner: Temporalio::Internal::Worker::MultiRunner,
      activation_completion: Object,
      encoded: T::Boolean,
      completion_complete_queue: Queue
    ).void
  end
  def handle_activation_complete(runner:, activation_completion:, encoded:, completion_complete_queue:); end

  sig { void }
  def on_shutdown_complete; end

  private

  sig { params(runner: Temporalio::Internal::Worker::MultiRunner, activation: Object).void }
  def decode_activation(runner, activation); end

  sig { params(runner: Temporalio::Internal::Worker::MultiRunner, activation_completion: Object).void }
  def encode_activation_completion(runner, activation_completion); end

  sig { params(payload_or_payloads: Object, block: T.proc.params(arg0: Object).returns(Object)).void }
  def apply_codec_on_payload_visit(payload_or_payloads, &block); end
end

class Temporalio::Internal::Worker::WorkflowWorker::State
  extend T::Sig

  sig { returns(T::Hash[T.nilable(String), Temporalio::Workflow::Definition::Info]) }
  def workflow_definitions; end

  sig { returns(Temporalio::Internal::Bridge::Worker) }
  def bridge_worker; end

  sig { returns(Logger) }
  def logger; end

  sig { returns(Temporalio::Metric::Meter) }
  def metric_meter; end

  sig { returns(Temporalio::Converters::DataConverter) }
  def data_converter; end

  sig { returns(T.nilable(Float)) }
  def deadlock_timeout; end

  sig { returns(T::Hash[String, Object]) }
  def illegal_calls; end

  sig { returns(String) }
  def namespace; end

  sig { returns(String) }
  def task_queue; end

  sig { returns(T::Boolean) }
  def disable_eager_activity_execution; end

  sig { returns(T::Array[Temporalio::Worker::Interceptor::Workflow]) }
  def workflow_interceptors; end

  sig { returns(T::Array[T.class_of(Exception)]) }
  def workflow_failure_exception_types; end

  sig { returns(T::Boolean) }
  def unsafe_workflow_io_enabled; end

  sig { returns(T.proc.params(arg0: String).void) }
  def assert_valid_local_activity; end

  sig { params(on_eviction: T.proc.params(arg0: String, arg1: Object).void).void }
  def on_eviction=(on_eviction); end

  sig do
    params(
      workflow_definitions: T::Hash[T.nilable(String), Temporalio::Workflow::Definition::Info],
      bridge_worker: Temporalio::Internal::Bridge::Worker,
      logger: Logger,
      metric_meter: Temporalio::Metric::Meter,
      data_converter: Temporalio::Converters::DataConverter,
      deadlock_timeout: T.nilable(Float),
      illegal_calls: T::Hash[String, Object],
      namespace: String,
      task_queue: String,
      disable_eager_activity_execution: T::Boolean,
      workflow_interceptors: T::Array[Temporalio::Worker::Interceptor::Workflow],
      workflow_failure_exception_types: T::Array[T.class_of(Exception)],
      unsafe_workflow_io_enabled: T::Boolean,
      assert_valid_local_activity: T.proc.params(arg0: String).void
    ).void
  end
  def initialize(
    workflow_definitions:,
    bridge_worker:,
    logger:,
    metric_meter:,
    data_converter:,
    deadlock_timeout:,
    illegal_calls:,
    namespace:,
    task_queue:,
    disable_eager_activity_execution:,
    workflow_interceptors:,
    workflow_failure_exception_types:,
    unsafe_workflow_io_enabled:,
    assert_valid_local_activity:
  ); end

  sig do
    type_parameters(:T)
      .params(run_id: String, block: T.proc.returns(T.type_parameter(:T)))
      .returns(T.type_parameter(:T))
  end
  def get_or_create_running_workflow(run_id, &block); end

  sig { params(run_id: String, cache_remove_job: Object).void }
  def evict_running_workflow(run_id, cache_remove_job); end

  sig { void }
  def evict_all; end
end
