# typed: true

class Temporalio::Internal::Client::Implementation < Temporalio::Client::Interceptor::Outbound
  extend T::Sig

  sig do
    params(
      user_rpc_options: T.nilable(Temporalio::Client::RPCOptions)
    ).returns(Temporalio::Client::RPCOptions)
  end
  def self.with_default_rpc_options(user_rpc_options); end

  sig { params(client: Temporalio::Client).void }
  def initialize(client); end

  sig do
    params(
      klass: Class,
      start_options: Temporalio::Client::WithStartWorkflowOperation::Options
    ).returns(Object)
  end
  def _start_workflow_request_from_with_start_options(klass, start_options); end
end
