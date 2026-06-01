# typed: true

# Sorbet RBI types for the Temporal Ruby SDK.
# This file was split from rbi/temporalio.rbi by extra/split_rbi.rb.

class Temporalio::Client::WorkflowUpdateHandle
  sig do
    params(
      client: Temporalio::Client,
      id: String,
      workflow_id: String,
      workflow_run_id: T.nilable(String),
      known_outcome: T.nilable(Object),
      result_hint: T.nilable(Object)
    ).void
  end
  def initialize(client:, id:, workflow_id:, workflow_run_id:, known_outcome:, result_hint:); end

  sig { returns(String) }
  def id; end

  sig { returns(String) }
  def workflow_id; end

  sig { returns(T.nilable(String)) }
  def workflow_run_id; end

  sig { returns(T.nilable(Object)) }
  def result_hint; end

  sig { returns(T::Boolean) }
  def result_obtained?; end

  sig do
    params(
      result_hint: T.nilable(Object),
      rpc_options: T.nilable(Temporalio::Client::RPCOptions)
    ).returns(T.nilable(Object))
  end
  def result(result_hint: T.unsafe(nil), rpc_options: T.unsafe(nil)); end
end
