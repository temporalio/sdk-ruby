# typed: true

class Temporalio::Internal::Worker::WorkflowInstance::Details
  extend T::Sig

  sig { returns(String) }
  def namespace; end

  sig { returns(String) }
  def task_queue; end

  sig { returns(Temporalio::Workflow::Definition::Info) }
  def definition; end

  sig { returns(Object) }
  def initial_activation; end

  sig { returns(Logger) }
  def logger; end

  sig { returns(Temporalio::Metric::Meter) }
  def metric_meter; end

  sig { returns(Temporalio::Converters::PayloadConverter) }
  def payload_converter; end

  sig { returns(Temporalio::Converters::FailureConverter) }
  def failure_converter; end

  sig { returns(T::Array[Temporalio::Worker::Interceptor::Workflow]) }
  def interceptors; end

  sig { returns(T::Boolean) }
  def disable_eager_activity_execution; end

  sig { returns(T::Hash[String, Object]) }
  def illegal_calls; end

  sig { returns(T::Array[T.class_of(Exception)]) }
  def workflow_failure_exception_types; end

  sig { returns(T::Boolean) }
  def unsafe_workflow_io_enabled; end

  sig { returns(T.proc.params(arg0: String).void) }
  def assert_valid_local_activity; end

  sig do
    params(
      namespace: String,
      task_queue: String,
      definition: Temporalio::Workflow::Definition::Info,
      initial_activation: Object,
      logger: Logger,
      metric_meter: Temporalio::Metric::Meter,
      payload_converter: Temporalio::Converters::PayloadConverter,
      failure_converter: Temporalio::Converters::FailureConverter,
      interceptors: T::Array[Temporalio::Worker::Interceptor::Workflow],
      disable_eager_activity_execution: T::Boolean,
      illegal_calls: T::Hash[String, Object],
      workflow_failure_exception_types: T::Array[T.class_of(Exception)],
      unsafe_workflow_io_enabled: T::Boolean,
      assert_valid_local_activity: T.proc.params(arg0: String).void
    ).void
  end
  def initialize(
    namespace:,
    task_queue:,
    definition:,
    initial_activation:,
    logger:,
    metric_meter:,
    payload_converter:,
    failure_converter:,
    interceptors:,
    disable_eager_activity_execution:,
    illegal_calls:,
    workflow_failure_exception_types:,
    unsafe_workflow_io_enabled:,
    assert_valid_local_activity:
  ); end
end
