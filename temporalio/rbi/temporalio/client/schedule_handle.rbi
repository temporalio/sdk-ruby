# typed: true

class Temporalio::Client::ScheduleHandle
  sig { params(client: Temporalio::Client, id: String).void }
  def initialize(client:, id:); end

  sig { returns(String) }
  attr_reader :id

  sig do
    params(
      backfills: Temporalio::Client::Schedule::Backfill,
      rpc_options: T.nilable(Temporalio::Client::RPCOptions)
    ).void
  end
  def backfill(*backfills, rpc_options: T.unsafe(nil)); end

  sig { params(rpc_options: T.nilable(Temporalio::Client::RPCOptions)).void }
  def delete(rpc_options: T.unsafe(nil)); end

  sig { params(rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Client::Schedule::Description) }
  def describe(rpc_options: T.unsafe(nil)); end

  sig { params(note: String, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).void }
  def pause(note: T.unsafe(nil), rpc_options: T.unsafe(nil)); end

  sig { params(overlap: T.nilable(Integer), rpc_options: T.nilable(Temporalio::Client::RPCOptions)).void }
  def trigger(overlap: T.unsafe(nil), rpc_options: T.unsafe(nil)); end

  sig { params(note: String, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).void }
  def unpause(note: T.unsafe(nil), rpc_options: T.unsafe(nil)); end

  sig do
    params(
      rpc_options: T.nilable(Temporalio::Client::RPCOptions),
      updater: T.proc.params(arg0: Temporalio::Client::Schedule::Update::Input).returns(T.nilable(Temporalio::Client::Schedule::Update))
    ).void
  end
  def update(rpc_options: T.unsafe(nil), &updater); end
end
