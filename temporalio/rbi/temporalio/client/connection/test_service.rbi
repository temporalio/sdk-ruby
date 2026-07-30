# typed: false
# frozen_string_literal: true

# Generated code.  DO NOT EDIT!

class Temporalio::Client::Connection::TestService < ::Temporalio::Client::Connection::Service
  extend T::Sig

  sig { params(connection: Temporalio::Client::Connection).void }
  def initialize(connection); end

  sig { params(request: Temporalio::Api::TestService::V1::LockTimeSkippingRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::TestService::V1::LockTimeSkippingResponse) }
  def lock_time_skipping(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::TestService::V1::UnlockTimeSkippingRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::TestService::V1::UnlockTimeSkippingResponse) }
  def unlock_time_skipping(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::TestService::V1::SleepRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::TestService::V1::SleepResponse) }
  def sleep(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::TestService::V1::SleepUntilRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::TestService::V1::SleepResponse) }
  def sleep_until(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::TestService::V1::SleepRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::TestService::V1::SleepResponse) }
  def unlock_time_skipping_with_sleep(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Google::Protobuf::Empty, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::TestService::V1::GetCurrentTimeResponse) }
  def get_current_time(request, rpc_options: T.unsafe(nil)); end
end
