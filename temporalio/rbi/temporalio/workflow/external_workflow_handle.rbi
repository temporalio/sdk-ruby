# typed: true

# Sorbet RBI types for the Temporal Ruby SDK.
# This file was split from rbi/temporalio.rbi by extra/split_rbi.rb.

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
      arg_hints: T.nilable(T::Array[Object])
    ).void
  end
  def signal(signal, *args, cancellation: T.unsafe(nil), arg_hints: T.unsafe(nil)); end

  sig { void }
  def cancel; end
end
