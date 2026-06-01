# typed: true

# Sorbet RBI types for the Temporal Ruby SDK.
# This file was split from rbi/temporalio.rbi by extra/split_rbi.rb.

class Temporalio::Client::WorkflowHandle
  sig do
    params(
      client: Temporalio::Client,
      id: String,
      run_id: T.nilable(String),
      result_run_id: T.nilable(String),
      first_execution_run_id: T.nilable(String),
      result_hint: T.nilable(Object)
    ).void
  end
  def initialize(client:, id:, run_id:, result_run_id:, first_execution_run_id:, result_hint:); end

  sig { returns(String) }
  def id; end

  sig { returns(T.nilable(String)) }
  def run_id; end

  sig { returns(T.nilable(String)) }
  def result_run_id; end

  sig { returns(T.nilable(String)) }
  def first_execution_run_id; end

  sig { returns(T.nilable(Object)) }
  def result_hint; end

  sig do
    params(
      follow_runs: T::Boolean,
      result_hint: T.nilable(Object),
      rpc_options: T.nilable(Temporalio::Client::RPCOptions)
    ).returns(T.nilable(Object))
  end
  def result(follow_runs: T.unsafe(nil), result_hint: T.unsafe(nil), rpc_options: T.unsafe(nil)); end

  sig do
    params(
      rpc_options: T.nilable(Temporalio::Client::RPCOptions)
    ).returns(Temporalio::Client::WorkflowExecution::Description)
  end
  def describe(rpc_options: T.unsafe(nil)); end

  sig do
    params(
      event_filter_type: Integer,
      skip_archival: T::Boolean,
      rpc_options: T.nilable(Temporalio::Client::RPCOptions)
    ).returns(Temporalio::WorkflowHistory)
  end
  def fetch_history(event_filter_type: T.unsafe(nil), skip_archival: T.unsafe(nil), rpc_options: T.unsafe(nil)); end

  sig do
    params(
      wait_new_event: T::Boolean,
      event_filter_type: Integer,
      skip_archival: T::Boolean,
      specific_run_id: T.nilable(String),
      rpc_options: T.nilable(Temporalio::Client::RPCOptions)
    ).returns(T::Enumerator[Temporalio::Api::History::V1::HistoryEvent])
  end
  def fetch_history_events(
    wait_new_event: T.unsafe(nil),
    event_filter_type: T.unsafe(nil),
    skip_archival: T.unsafe(nil),
    specific_run_id: T.unsafe(nil),
    rpc_options: T.unsafe(nil)
  ); end

  sig do
    params(
      signal: T.any(Temporalio::Workflow::Definition::Signal, Symbol, String),
      args: T.nilable(Object),
      arg_hints: T.nilable(T::Array[Object]),
      rpc_options: T.nilable(Temporalio::Client::RPCOptions)
    ).void
  end
  def signal(signal, *args, arg_hints: T.unsafe(nil), rpc_options: T.unsafe(nil)); end

  sig do
    params(
      query: T.any(Temporalio::Workflow::Definition::Query, Symbol, String),
      args: T.nilable(Object),
      reject_condition: T.nilable(Integer),
      arg_hints: T.nilable(T::Array[Object]),
      result_hint: T.nilable(Object),
      rpc_options: T.nilable(Temporalio::Client::RPCOptions)
    ).returns(T.nilable(Object))
  end
  def query(query, *args, reject_condition: T.unsafe(nil), arg_hints: T.unsafe(nil), result_hint: T.unsafe(nil), rpc_options: T.unsafe(nil)); end

  sig do
    params(
      update: T.any(Temporalio::Workflow::Definition::Update, Symbol, String),
      args: T.nilable(Object),
      wait_for_stage: Integer,
      id: String,
      arg_hints: T.nilable(T::Array[Object]),
      result_hint: T.nilable(Object),
      rpc_options: T.nilable(Temporalio::Client::RPCOptions)
    ).returns(Temporalio::Client::WorkflowUpdateHandle)
  end
  def start_update(
    update,
    *args,
    wait_for_stage:,
    id: T.unsafe(nil),
    arg_hints: T.unsafe(nil),
    result_hint: T.unsafe(nil),
    rpc_options: T.unsafe(nil)
  ); end

  sig do
    params(
      update: T.any(Temporalio::Workflow::Definition::Update, Symbol, String),
      args: T.nilable(Object),
      id: String,
      arg_hints: T.nilable(T::Array[Object]),
      result_hint: T.nilable(Object),
      rpc_options: T.nilable(Temporalio::Client::RPCOptions)
    ).returns(T.nilable(Object))
  end
  def execute_update(update, *args, id: T.unsafe(nil), arg_hints: T.unsafe(nil), result_hint: T.unsafe(nil), rpc_options: T.unsafe(nil)); end

  sig do
    params(
      id: String,
      specific_run_id: T.nilable(String),
      result_hint: T.nilable(Object)
    ).returns(Temporalio::Client::WorkflowUpdateHandle)
  end
  def update_handle(id, specific_run_id: T.unsafe(nil), result_hint: T.unsafe(nil)); end

  sig { params(rpc_options: T.nilable(Temporalio::Client::RPCOptions)).void }
  def cancel(rpc_options: T.unsafe(nil)); end

  sig do
    params(
      reason: T.nilable(String),
      details: T::Array[T.nilable(Object)],
      rpc_options: T.nilable(Temporalio::Client::RPCOptions)
    ).void
  end
  def terminate(reason = T.unsafe(nil), details: T.unsafe(nil), rpc_options: T.unsafe(nil)); end
end
