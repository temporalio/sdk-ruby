# typed: true

class Temporalio::Internal::Bridge::Client
  extend T::Sig

  SERVICE_WORKFLOW = T.let(T.unsafe(nil), Integer)
  SERVICE_OPERATOR = T.let(T.unsafe(nil), Integer)
  SERVICE_CLOUD = T.let(T.unsafe(nil), Integer)
  SERVICE_TEST = T.let(T.unsafe(nil), Integer)
  SERVICE_HEALTH = T.let(T.unsafe(nil), Integer)

  sig do
    params(
      runtime: Temporalio::Internal::Bridge::Runtime,
      options: Temporalio::Internal::Bridge::Client::Options
    ).returns(Temporalio::Internal::Bridge::Client)
  end
  def self.new(runtime, options); end

  sig do
    params(
      runtime: Temporalio::Internal::Bridge::Runtime,
      options: Temporalio::Internal::Bridge::Client::Options,
      queue: Queue
    ).void
  end
  def self.async_new(runtime, options, queue); end

  sig do
    params(
      service: Integer,
      rpc: String,
      request: String,
      rpc_retry: T::Boolean,
      rpc_metadata: T.nilable(T::Hash[String, String]),
      rpc_timeout: T.nilable(T.any(Integer, Float)),
      rpc_cancellation_token: T.nilable(Temporalio::Internal::Bridge::Client::CancellationToken),
      queue: Queue
    ).void
  end
  def async_invoke_rpc(
    service:,
    rpc:,
    request:,
    rpc_retry:,
    rpc_metadata:,
    rpc_timeout:,
    rpc_cancellation_token:,
    queue:
  ); end

  sig { params(rpc_metadata: T::Hash[String, String]).void }
  def update_metadata(rpc_metadata); end

  sig { params(api_key: T.nilable(String)).void }
  def update_api_key(api_key); end
end

class Temporalio::Internal::Bridge::Client::Options < ::Struct
  extend T::Sig

  sig do
    params(
      target_host: String,
      client_name: String,
      client_version: String,
      rpc_metadata: T::Hash[String, String],
      api_key: T.nilable(String),
      identity: String,
      tls: T.nilable(Temporalio::Internal::Bridge::Client::TLSOptions),
      rpc_retry: Temporalio::Internal::Bridge::Client::RPCRetryOptions,
      keep_alive: T.nilable(Temporalio::Internal::Bridge::Client::KeepAliveOptions),
      http_connect_proxy: T.nilable(Temporalio::Internal::Bridge::Client::HTTPConnectProxyOptions),
      dns_load_balancing: T.nilable(Temporalio::Internal::Bridge::Client::DnsLoadBalancingOptions)
    ).void
  end
  def initialize(
    target_host,
    client_name,
    client_version,
    rpc_metadata,
    api_key,
    identity,
    tls,
    rpc_retry,
    keep_alive,
    http_connect_proxy,
    dns_load_balancing
  ); end

  sig { returns(String) }
  def target_host; end

  sig { params(_: String).void }
  def target_host=(_); end

  sig { returns(String) }
  def client_name; end

  sig { params(_: String).void }
  def client_name=(_); end

  sig { returns(String) }
  def client_version; end

  sig { params(_: String).void }
  def client_version=(_); end

  sig { returns(T::Hash[String, String]) }
  def rpc_metadata; end

  sig { params(_: T::Hash[String, String]).void }
  def rpc_metadata=(_); end

  sig { returns(T.nilable(String)) }
  def api_key; end

  sig { params(_: T.nilable(String)).void }
  def api_key=(_); end

  sig { returns(String) }
  def identity; end

  sig { params(_: String).void }
  def identity=(_); end

  sig { returns(T.nilable(Temporalio::Internal::Bridge::Client::TLSOptions)) }
  def tls; end

  sig { params(_: T.nilable(Temporalio::Internal::Bridge::Client::TLSOptions)).void }
  def tls=(_); end

  sig { returns(Temporalio::Internal::Bridge::Client::RPCRetryOptions) }
  def rpc_retry; end

  sig { params(_: Temporalio::Internal::Bridge::Client::RPCRetryOptions).void }
  def rpc_retry=(_); end

  sig { returns(T.nilable(Temporalio::Internal::Bridge::Client::KeepAliveOptions)) }
  def keep_alive; end

  sig { params(_: T.nilable(Temporalio::Internal::Bridge::Client::KeepAliveOptions)).void }
  def keep_alive=(_); end

  sig { returns(T.nilable(Temporalio::Internal::Bridge::Client::HTTPConnectProxyOptions)) }
  def http_connect_proxy; end

  sig { params(_: T.nilable(Temporalio::Internal::Bridge::Client::HTTPConnectProxyOptions)).void }
  def http_connect_proxy=(_); end

  sig { returns(T.nilable(Temporalio::Internal::Bridge::Client::DnsLoadBalancingOptions)) }
  def dns_load_balancing; end

  sig { params(_: T.nilable(Temporalio::Internal::Bridge::Client::DnsLoadBalancingOptions)).void }
  def dns_load_balancing=(_); end
end

class Temporalio::Internal::Bridge::Client::TLSOptions < ::Struct
  extend T::Sig

  sig do
    params(
      client_cert: T.nilable(String),
      client_private_key: T.nilable(String),
      server_root_ca_cert: T.nilable(String),
      domain: T.nilable(String)
    ).void
  end
  def initialize(
    client_cert = T.unsafe(nil),
    client_private_key = T.unsafe(nil),
    server_root_ca_cert = T.unsafe(nil),
    domain = T.unsafe(nil)
  ); end

  sig { returns(T.nilable(String)) }
  def client_cert; end

  sig { params(_: T.nilable(String)).void }
  def client_cert=(_); end

  sig { returns(T.nilable(String)) }
  def client_private_key; end

  sig { params(_: T.nilable(String)).void }
  def client_private_key=(_); end

  sig { returns(T.nilable(String)) }
  def server_root_ca_cert; end

  sig { params(_: T.nilable(String)).void }
  def server_root_ca_cert=(_); end

  sig { returns(T.nilable(String)) }
  def domain; end

  sig { params(_: T.nilable(String)).void }
  def domain=(_); end
end

class Temporalio::Internal::Bridge::Client::RPCRetryOptions < ::Struct
  extend T::Sig

  sig do
    params(
      initial_interval: T.any(Integer, Float),
      randomization_factor: T.any(Integer, Float),
      multiplier: T.any(Integer, Float),
      max_interval: T.any(Integer, Float),
      max_elapsed_time: T.any(Integer, Float),
      max_retries: Integer
    ).void
  end
  def initialize(initial_interval, randomization_factor, multiplier, max_interval, max_elapsed_time, max_retries); end

  sig { returns(T.any(Integer, Float)) }
  def initial_interval; end

  sig { params(_: T.any(Integer, Float)).void }
  def initial_interval=(_); end

  sig { returns(T.any(Integer, Float)) }
  def randomization_factor; end

  sig { params(_: T.any(Integer, Float)).void }
  def randomization_factor=(_); end

  sig { returns(T.any(Integer, Float)) }
  def multiplier; end

  sig { params(_: T.any(Integer, Float)).void }
  def multiplier=(_); end

  sig { returns(T.any(Integer, Float)) }
  def max_interval; end

  sig { params(_: T.any(Integer, Float)).void }
  def max_interval=(_); end

  sig { returns(T.any(Integer, Float)) }
  def max_elapsed_time; end

  sig { params(_: T.any(Integer, Float)).void }
  def max_elapsed_time=(_); end

  sig { returns(Integer) }
  def max_retries; end

  sig { params(_: Integer).void }
  def max_retries=(_); end
end

class Temporalio::Internal::Bridge::Client::KeepAliveOptions < ::Struct
  extend T::Sig

  sig { params(interval: T.any(Integer, Float), timeout: T.any(Integer, Float)).void }
  def initialize(interval, timeout); end

  sig { returns(T.any(Integer, Float)) }
  def interval; end

  sig { params(_: T.any(Integer, Float)).void }
  def interval=(_); end

  sig { returns(T.any(Integer, Float)) }
  def timeout; end

  sig { params(_: T.any(Integer, Float)).void }
  def timeout=(_); end
end

class Temporalio::Internal::Bridge::Client::HTTPConnectProxyOptions < ::Struct
  extend T::Sig

  sig { params(target_host: String, basic_auth_user: T.nilable(String), basic_auth_pass: T.nilable(String)).void }
  def initialize(target_host, basic_auth_user, basic_auth_pass); end

  sig { returns(String) }
  def target_host; end

  sig { params(_: String).void }
  def target_host=(_); end

  sig { returns(T.nilable(String)) }
  def basic_auth_user; end

  sig { params(_: T.nilable(String)).void }
  def basic_auth_user=(_); end

  sig { returns(T.nilable(String)) }
  def basic_auth_pass; end

  sig { params(_: T.nilable(String)).void }
  def basic_auth_pass=(_); end
end

class Temporalio::Internal::Bridge::Client::DnsLoadBalancingOptions < ::Struct
  extend T::Sig

  sig { params(resolution_interval: T.any(Integer, Float)).void }
  def initialize(resolution_interval); end

  sig { returns(T.any(Integer, Float)) }
  def resolution_interval; end

  sig { params(_: T.any(Integer, Float)).void }
  def resolution_interval=(_); end
end

class Temporalio::Internal::Bridge::Client::RPCFailure < Temporalio::Error
  extend T::Sig

  sig { returns(Integer) }
  def code; end

  sig { returns(String) }
  def message; end

  sig { returns(T.nilable(String)) }
  def details; end
end

class Temporalio::Internal::Bridge::Client::CancellationToken
  extend T::Sig

  sig { returns(Temporalio::Internal::Bridge::Client::CancellationToken) }
  def self.new; end

  sig { void }
  def cancel; end
end
