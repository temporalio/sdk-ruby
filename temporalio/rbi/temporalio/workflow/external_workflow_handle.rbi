# typed: true

class Temporalio::Workflow::ExternalWorkflowHandle
  extend T::Sig

  sig { returns(String) }
  def id; end

  sig { returns(T.nilable(String)) }
  def run_id; end

  sig do
    params(
      signal: T.any(Temporalio::Workflow::Definition::Signal, Symbol, String),
      args: T.nilable(Object),
      cancellation: Temporalio::Cancellation,
      arg_hints: T.nilable(T::Array[Object]),
      event_groups: T.nilable(T::Array[Temporalio::Workflow::EventGroup])
    ).void
  end
  def signal(signal, *args, cancellation: T.unsafe(nil), arg_hints: T.unsafe(nil), event_groups: T.unsafe(nil)); end

  sig { params(event_groups: T.nilable(T::Array[Temporalio::Workflow::EventGroup])).void }
  def cancel(event_groups: nil); end
end
