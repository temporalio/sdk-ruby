# typed: true

class Temporalio::Client::Connection::Service
  sig { params(connection: Temporalio::Client::Connection, service: Integer).void }
  def initialize(connection, service); end

  protected

  sig do
    params(
      rpc: String,
      request_class: T.class_of(Object),
      response_class: T.class_of(Object),
      request: Object,
      rpc_options: T.nilable(Temporalio::Client::RPCOptions)
    ).returns(Object)
  end
  def invoke_rpc(rpc:, request_class:, response_class:, request:, rpc_options:); end
end
