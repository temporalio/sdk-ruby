# typed: true

class Temporalio::Client::ActivityHandle
  sig do
    params(
      client: Temporalio::Client,
      id: String,
      run_id: T.nilable(String),
      result_hint: T.nilable(Object)
    ).void
  end
  def initialize(client:, id:, run_id:, result_hint:); end

  sig { returns(String) }
  attr_reader :id

  sig { returns(T.nilable(String)) }
  attr_reader :run_id

  sig { returns(T.nilable(Object)) }
  attr_reader :result_hint

  sig do
    params(
      result_hint: T.nilable(Object),
      rpc_options: T.nilable(Temporalio::Client::RPCOptions)
    ).returns(T.nilable(Object))
  end
  def result(result_hint: T.unsafe(nil), rpc_options: T.unsafe(nil)); end

  sig { params(rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Client::ActivityExecution::Description) }
  def describe(rpc_options: T.unsafe(nil)); end

  sig { params(reason: T.nilable(String), rpc_options: T.nilable(Temporalio::Client::RPCOptions)).void }
  def cancel(reason = T.unsafe(nil), rpc_options: T.unsafe(nil)); end

  sig { params(reason: T.nilable(String), rpc_options: T.nilable(Temporalio::Client::RPCOptions)).void }
  def terminate(reason = T.unsafe(nil), rpc_options: T.unsafe(nil)); end

  private

  sig do
    params(
      outcome: T.nilable(Temporalio::Api::Activity::V1::ActivityExecutionOutcome),
      hint: T.nilable(Object)
    ).returns(T.nilable(Object))
  end
  def _process_outcome(outcome, hint); end
end
