# typed: true

class Temporalio::Client::ActivityHandle
  UPDATABLE_OPTION_PATHS = T.let(T.unsafe(nil), T::Hash[Symbol, String])

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

  sig do
    params(
      include_input: T::Boolean,
      include_outcome: T::Boolean,
      include_heartbeat_details: T::Boolean,
      include_last_failure: T::Boolean,
      rpc_options: T.nilable(Temporalio::Client::RPCOptions)
    ).returns(Temporalio::Client::ActivityExecution::Description)
  end
  def describe(
    include_input: T.unsafe(nil),
    include_outcome: T.unsafe(nil),
    include_heartbeat_details: T.unsafe(nil),
    include_last_failure: T.unsafe(nil),
    rpc_options: T.unsafe(nil)
  ); end

  sig { params(reason: T.nilable(String), rpc_options: T.nilable(Temporalio::Client::RPCOptions)).void }
  def cancel(reason = T.unsafe(nil), rpc_options: T.unsafe(nil)); end

  sig { params(reason: T.nilable(String), rpc_options: T.nilable(Temporalio::Client::RPCOptions)).void }
  def terminate(reason = T.unsafe(nil), rpc_options: T.unsafe(nil)); end

  sig { params(reason: T.nilable(String), rpc_options: T.nilable(Temporalio::Client::RPCOptions)).void }
  def pause(reason = T.unsafe(nil), rpc_options: T.unsafe(nil)); end

  sig do
    params(
      reason: T.nilable(String),
      jitter: T.nilable(Float),
      rpc_options: T.nilable(Temporalio::Client::RPCOptions)
    ).void
  end
  def unpause(reason: T.unsafe(nil), jitter: T.unsafe(nil), rpc_options: T.unsafe(nil)); end

  sig do
    params(
      keep_paused: T::Boolean,
      jitter: T.nilable(Float),
      restore_original_options: T::Boolean,
      reset_heartbeat: T::Boolean,
      rpc_options: T.nilable(Temporalio::Client::RPCOptions)
    ).void
  end
  def reset(
    keep_paused: T.unsafe(nil),
    jitter: T.unsafe(nil),
    restore_original_options: T.unsafe(nil),
    reset_heartbeat: T.unsafe(nil),
    rpc_options: T.unsafe(nil)
  ); end

  sig do
    params(
      updates: Temporalio::Client::ActivityOptions::Update,
      restore_original: T::Boolean,
      rpc_options: T.nilable(Temporalio::Client::RPCOptions)
    ).returns(Temporalio::Client::ActivityExecutionOptions)
  end
  def update_options(
    *updates,
    restore_original: T.unsafe(nil),
    rpc_options: T.unsafe(nil)
  ); end

  private

  sig do
    params(
      outcome: T.nilable(Temporalio::Api::Activity::V1::ActivityExecutionOutcome),
      hint: T.nilable(Object)
    ).returns(T.nilable(Object))
  end
  def _process_outcome(outcome, hint); end
end
