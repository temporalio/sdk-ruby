# typed: true

# Sorbet RBI types for the Temporal Ruby SDK.
# This file was split from rbi/temporalio.rbi by extra/split_rbi.rb.

class Temporalio::Client::Connection
  sig do
    params(
      target_host: String,
      api_key: T.nilable(String),
      tls: T.nilable(T.any(T::Boolean, Temporalio::Client::Connection::TLSOptions)),
      rpc_metadata: T::Hash[String, String],
      rpc_retry: Temporalio::Client::Connection::RPCRetryOptions,
      identity: String,
      keep_alive: Temporalio::Client::Connection::KeepAliveOptions,
      http_connect_proxy: T.nilable(Temporalio::Client::Connection::HTTPConnectProxyOptions),
      runtime: Temporalio::Runtime,
      lazy_connect: T::Boolean,
      dns_load_balancing: T.nilable(Temporalio::Client::Connection::DnsLoadBalancingOptions),
      around_connect: T.nilable(T.proc.params(arg0: Temporalio::Client::Connection::Options, arg1: T.proc.params(arg0: Temporalio::Client::Connection::Options).void).void)
    ).void
  end
  def initialize(
    target_host:,
    api_key: T.unsafe(nil),
    tls: T.unsafe(nil),
    rpc_metadata: T.unsafe(nil),
    rpc_retry: T.unsafe(nil),
    identity: T.unsafe(nil),
    keep_alive: T.unsafe(nil),
    http_connect_proxy: T.unsafe(nil),
    runtime: T.unsafe(nil),
    lazy_connect: T.unsafe(nil),
    dns_load_balancing: T.unsafe(nil),
    around_connect: T.unsafe(nil)
  ); end

  sig { returns(Temporalio::Client::Connection::Options) }
  attr_reader :options

  sig { returns(Temporalio::Client::Connection::WorkflowService) }
  attr_reader :workflow_service

  sig { returns(Temporalio::Client::Connection::OperatorService) }
  attr_reader :operator_service

  sig { returns(Temporalio::Client::Connection::CloudService) }
  attr_reader :cloud_service

  sig { returns(String) }
  def target_host; end

  sig { returns(String) }
  def identity; end

  sig { returns(T::Boolean) }
  def connected?; end

  sig { returns(T.nilable(String)) }
  def api_key; end

  sig { params(new_key: T.nilable(String)).void }
  def api_key=(new_key); end

  sig { returns(T::Hash[String, String]) }
  def rpc_metadata; end

  sig { params(rpc_metadata: T::Hash[String, String]).void }
  def rpc_metadata=(rpc_metadata); end
end

class Temporalio::Client::Connection::Options < ::Data
  sig { returns(String) }
  def target_host; end

  sig { returns(T.nilable(String)) }
  def api_key; end

  sig { returns(T.nilable(T.any(T::Boolean, Temporalio::Client::Connection::TLSOptions))) }
  def tls; end

  sig { returns(T::Hash[String, String]) }
  def rpc_metadata; end

  sig { returns(Temporalio::Client::Connection::RPCRetryOptions) }
  def rpc_retry; end

  sig { returns(String) }
  def identity; end

  sig { returns(Temporalio::Client::Connection::KeepAliveOptions) }
  def keep_alive; end

  sig { returns(T.nilable(Temporalio::Client::Connection::HTTPConnectProxyOptions)) }
  def http_connect_proxy; end

  sig { returns(Temporalio::Runtime) }
  def runtime; end

  sig { returns(T::Boolean) }
  def lazy_connect; end

  sig { returns(T.nilable(Temporalio::Client::Connection::DnsLoadBalancingOptions)) }
  def dns_load_balancing; end

  sig { returns(T::Hash[Symbol, T.untyped]) }
  def to_h; end

  sig { params(kwargs: T.untyped).returns(Temporalio::Client::Connection::Options) }
  def with(**kwargs); end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Client::Connection::Options) }
    def new(*args); end

    sig { params(args: T.untyped).returns(Temporalio::Client::Connection::Options) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end

class Temporalio::Client::Connection::TLSOptions < ::Data
  sig do
    params(
      client_cert: T.nilable(String),
      client_private_key: T.nilable(String),
      server_root_ca_cert: T.nilable(String),
      domain: T.nilable(String)
    ).void
  end
  def initialize(client_cert: T.unsafe(nil), client_private_key: T.unsafe(nil), server_root_ca_cert: T.unsafe(nil), domain: T.unsafe(nil)); end

  sig { returns(T.nilable(String)) }
  def client_cert; end

  sig { returns(T.nilable(String)) }
  def client_private_key; end

  sig { returns(T.nilable(String)) }
  def server_root_ca_cert; end

  sig { returns(T.nilable(String)) }
  def domain; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Client::Connection::TLSOptions) }
    def new(*args); end

    sig { params(args: T.untyped).returns(Temporalio::Client::Connection::TLSOptions) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end

class Temporalio::Client::Connection::RPCRetryOptions < ::Data
  sig do
    params(
      initial_interval: Float,
      randomization_factor: Float,
      multiplier: Float,
      max_interval: Float,
      max_elapsed_time: Float,
      max_retries: Integer
    ).void
  end
  def initialize(
    initial_interval: T.unsafe(nil),
    randomization_factor: T.unsafe(nil),
    multiplier: T.unsafe(nil),
    max_interval: T.unsafe(nil),
    max_elapsed_time: T.unsafe(nil),
    max_retries: T.unsafe(nil)
  ); end

  sig { returns(Float) }
  def initial_interval; end

  sig { returns(Float) }
  def randomization_factor; end

  sig { returns(Float) }
  def multiplier; end

  sig { returns(Float) }
  def max_interval; end

  sig { returns(Float) }
  def max_elapsed_time; end

  sig { returns(Integer) }
  def max_retries; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Client::Connection::RPCRetryOptions) }
    def new(*args); end

    sig { params(args: T.untyped).returns(Temporalio::Client::Connection::RPCRetryOptions) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end

class Temporalio::Client::Connection::KeepAliveOptions < ::Data
  sig { params(interval: Float, timeout: Float).void }
  def initialize(interval: T.unsafe(nil), timeout: T.unsafe(nil)); end

  sig { returns(Float) }
  def interval; end

  sig { returns(Float) }
  def timeout; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Client::Connection::KeepAliveOptions) }
    def new(*args); end

    sig { params(args: T.untyped).returns(Temporalio::Client::Connection::KeepAliveOptions) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end

class Temporalio::Client::Connection::HTTPConnectProxyOptions < ::Data
  sig { returns(String) }
  def target_host; end

  sig { returns(T.nilable(String)) }
  def basic_auth_user; end

  sig { returns(T.nilable(String)) }
  def basic_auth_pass; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Client::Connection::HTTPConnectProxyOptions) }
    def new(*args); end

    sig { params(args: T.untyped).returns(Temporalio::Client::Connection::HTTPConnectProxyOptions) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end

class Temporalio::Client::Connection::DnsLoadBalancingOptions < ::Data
  sig { params(resolution_interval: Float).void }
  def initialize(resolution_interval: T.unsafe(nil)); end

  sig { returns(Float) }
  def resolution_interval; end

  class << self
    sig { params(resolution_interval: Float).returns(Temporalio::Client::Connection::DnsLoadBalancingOptions) }
    def new(resolution_interval: T.unsafe(nil)); end

    sig { params(resolution_interval: Float).returns(Temporalio::Client::Connection::DnsLoadBalancingOptions) }
    def [](resolution_interval: T.unsafe(nil)); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end
