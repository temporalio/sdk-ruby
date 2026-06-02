# typed: true

# Sorbet RBI types for the Temporal Ruby SDK.
# This file was split from rbi/temporalio.rbi by extra/split_rbi.rb.

class Temporalio::Client::AsyncActivityHandle
  sig { params(client: Temporalio::Client, task_token: T.nilable(String), id_reference: T.nilable(Temporalio::Client::ActivityIDReference)).void }
  def initialize(client:, task_token:, id_reference:); end

  sig { returns(T.nilable(String)) }
  attr_reader :task_token

  sig { returns(T.nilable(Temporalio::Client::ActivityIDReference)) }
  attr_reader :id_reference

  sig do
    params(
      details: T.nilable(Object),
      detail_hints: T.nilable(T::Array[Object]),
      rpc_options: T.nilable(Temporalio::Client::RPCOptions)
    ).void
  end
  def heartbeat(*details, detail_hints: T.unsafe(nil), rpc_options: T.unsafe(nil)); end

  sig do
    params(
      result: T.nilable(Object),
      result_hint: T.nilable(Object),
      rpc_options: T.nilable(Temporalio::Client::RPCOptions)
    ).void
  end
  def complete(result = T.unsafe(nil), result_hint: T.unsafe(nil), rpc_options: T.unsafe(nil)); end

  sig do
    params(
      error: Exception,
      last_heartbeat_details: T::Array[T.nilable(Object)],
      last_heartbeat_detail_hints: T.nilable(T::Array[Object]),
      rpc_options: T.nilable(Temporalio::Client::RPCOptions)
    ).void
  end
  def fail(error, last_heartbeat_details: T.unsafe(nil), last_heartbeat_detail_hints: T.unsafe(nil), rpc_options: T.unsafe(nil)); end

  sig do
    params(
      details: T.nilable(Object),
      detail_hints: T.nilable(T::Array[Object]),
      rpc_options: T.nilable(Temporalio::Client::RPCOptions)
    ).void
  end
  def report_cancellation(*details, detail_hints: T.unsafe(nil), rpc_options: T.unsafe(nil)); end
end
