# typed: true

class Temporalio::Internal::Worker::WorkflowInstance::OutboundImplementation < Temporalio::Worker::Interceptor::Workflow::Outbound
  extend T::Sig

  sig { params(instance: Temporalio::Internal::Worker::WorkflowInstance).void }
  def initialize(instance); end

  sig do
    params(
      local: T::Boolean,
      cancellation: Temporalio::Cancellation,
      result_hint: T.nilable(Object),
      block: T.proc.params(arg0: T.nilable(Object)).returns(Integer)
    ).returns(T.nilable(Object))
  end
  def execute_activity_with_local_backoffs(local:, cancellation:, result_hint:, &block); end

  sig do
    params(
      local: T::Boolean,
      cancellation: Temporalio::Cancellation,
      last_local_backoff: T.nilable(Object),
      result_hint: T.nilable(Object),
      block: T.proc.params(arg0: T.nilable(Object)).returns(Integer)
    ).returns(T.nilable(Object))
  end
  def execute_activity_once(local:, cancellation:, last_local_backoff:, result_hint:, &block); end

  sig do
    params(
      id: String,
      run_id: T.nilable(String),
      child: T::Boolean,
      signal: T.any(Temporalio::Workflow::Definition::Signal, Symbol, String),
      args: T::Array[T.nilable(Object)],
      cancellation: Temporalio::Cancellation,
      arg_hints: T.nilable(T::Array[Object]),
      headers: T::Hash[String, T.nilable(Object)]
    ).void
  end
  def _signal_external_workflow(id:, run_id:, child:, signal:, args:, cancellation:, arg_hints:, headers:); end
end
