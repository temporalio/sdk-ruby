# typed: true

class Temporalio::Internal::Worker::WorkflowInstance::Details
  extend T::Sig

  sig { returns(String) }
  attr_reader :namespace

  sig { returns(String) }
  attr_reader :task_queue

  sig { returns(Temporalio::Workflow::Definition::Info) }
  attr_reader :definition

  sig { returns(Object) }
  attr_reader :initial_activation

  sig { returns(Logger) }
  attr_reader :logger

  sig { returns(Temporalio::Metric::Meter) }
  attr_reader :metric_meter

  sig { returns(Temporalio::Converters::PayloadConverter) }
  attr_reader :payload_converter

  sig { returns(Temporalio::Converters::FailureConverter) }
  attr_reader :failure_converter

  sig { returns(T::Array[Temporalio::Worker::Interceptor::Workflow]) }
  attr_reader :interceptors

  sig { returns(T::Boolean) }
  attr_reader :disable_eager_activity_execution

  sig { returns(T::Hash[String, Object]) }
  attr_reader :illegal_calls

  sig { returns(T::Array[T.class_of(Exception)]) }
  attr_reader :workflow_failure_exception_types

  sig { returns(T::Boolean) }
  attr_reader :unsafe_workflow_io_enabled

  sig { returns(T.nilable(T.proc.params(input: Temporalio::Worker::PatchActivationInput).returns(T::Boolean))) }
  attr_reader :patch_activation_callback

  sig { returns(T.proc.params(arg0: String).void) }
  attr_reader :assert_valid_local_activity

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
      patch_activation_callback: T.nilable(T.proc.params(input: Temporalio::Worker::PatchActivationInput).returns(T::Boolean)),
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
    patch_activation_callback:,
    assert_valid_local_activity:
  ); end
end
