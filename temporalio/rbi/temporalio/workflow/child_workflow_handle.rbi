# typed: true

class Temporalio::Workflow::ChildWorkflowHandle
  extend T::Sig

  sig { returns(String) }
  def id; end

  sig { returns(String) }
  def first_execution_run_id; end

  sig { returns(T.nilable(Object)) }
  def result_hint; end

  sig { params(result_hint: T.nilable(Object)).returns(T.nilable(Object)) }
  def result(result_hint: T.unsafe(nil)); end

  sig do
    params(
      signal: T.any(Temporalio::Workflow::Definition::Signal, Symbol, String),
      args: T.nilable(Object),
      cancellation: Temporalio::Cancellation,
      arg_hints: T.nilable(T::Array[Object])
    ).void
  end
  def signal(signal, *args, cancellation: T.unsafe(nil), arg_hints: T.unsafe(nil)); end
end
