# typed: true

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
  attr_reader :id

  sig { returns(String) }
  attr_reader :workflow_id

  sig { returns(T.nilable(String)) }
  attr_reader :workflow_run_id

  sig { returns(T.nilable(Object)) }
  attr_reader :result_hint

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
