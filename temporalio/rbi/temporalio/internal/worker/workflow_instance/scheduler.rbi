# typed: true

class Temporalio::Internal::Worker::WorkflowInstance::Scheduler
  extend T::Sig

  sig { params(instance: Temporalio::Internal::Worker::WorkflowInstance).void }
  def initialize(instance); end

  sig { returns(Temporalio::Internal::Worker::WorkflowInstance::Context) }
  def context; end

  sig { void }
  def run_until_all_yielded; end

  sig do
    type_parameters(:T)
      .params(cancellation: T.nilable(Temporalio::Cancellation), block: T.proc.returns(T.type_parameter(:T)))
      .returns(T.type_parameter(:T))
  end
  def wait_condition(cancellation:, &block); end

  sig { returns(String) }
  def stack_trace; end

  sig do
    type_parameters(:T)
      .params(
        duration: T.nilable(T.any(Integer, Float)),
        exception_class: T.class_of(Exception),
        exception_arguments: T.nilable(Object),
        block: T.proc.returns(T.type_parameter(:T))
      )
      .returns(T.type_parameter(:T))
  end
  def timeout_after(duration, exception_class, *exception_arguments, &block); end
end
