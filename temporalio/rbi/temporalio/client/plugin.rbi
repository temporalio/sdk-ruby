# typed: true

module Temporalio::Client::Plugin
  sig { returns(String) }
  def name; end

  sig { params(options: Temporalio::Client::Options).returns(Temporalio::Client::Options) }
  def configure_client(options); end

  sig do
    params(
      options: Temporalio::Client::Connection::Options,
      next_call: T.proc.params(arg0: Temporalio::Client::Connection::Options).returns(Temporalio::Client::Connection)
    ).returns(Temporalio::Client::Connection)
  end
  def connect_client(options, next_call); end
end
