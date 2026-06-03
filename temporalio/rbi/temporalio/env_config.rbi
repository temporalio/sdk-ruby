# typed: true

# Sorbet RBI types for the Temporal Ruby SDK.
# This file was split from rbi/temporalio.rbi by extra/split_rbi.rb.

module Temporalio::EnvConfig; end

class Temporalio::EnvConfig::ClientConfigTLS < ::Data
  extend T::Sig

  sig { returns(T.nilable(T::Boolean)) }
  def disabled; end

  sig { returns(T.nilable(String)) }
  def server_name; end

  sig { returns(T.nilable(T.any(Pathname, String))) }
  def server_root_ca_cert; end

  sig { returns(T.nilable(T.any(Pathname, String))) }
  def client_cert; end

  sig { returns(T.nilable(T.any(Pathname, String))) }
  def client_private_key; end

  sig do
    params(
      disabled: T.nilable(T::Boolean),
      server_name: T.nilable(String),
      server_root_ca_cert: T.nilable(T.any(Pathname, String)),
      client_cert: T.nilable(T.any(Pathname, String)),
      client_private_key: T.nilable(T.any(Pathname, String))
    ).void
  end
  def initialize(
    disabled: T.unsafe(nil),
    server_name: T.unsafe(nil),
    server_root_ca_cert: T.unsafe(nil),
    client_cert: T.unsafe(nil),
    client_private_key: T.unsafe(nil)
  ); end

  sig { returns(T::Hash[Symbol, Object]) }
  def to_h; end

  sig { returns(T.any(Temporalio::Client::Connection::TLSOptions, FalseClass)) }
  def to_client_tls_options; end

  sig { params(hash: T.nilable(T::Hash[Symbol, Object])).returns(T.nilable(Temporalio::EnvConfig::ClientConfigTLS)) }
  def self.from_h(hash); end
end

class Temporalio::EnvConfig::ClientConfigProfile < ::Data
  extend T::Sig

  sig { returns(T.nilable(String)) }
  def address; end

  sig { returns(T.nilable(String)) }
  def namespace; end

  sig { returns(T.nilable(String)) }
  def api_key; end

  sig { returns(T.nilable(Temporalio::EnvConfig::ClientConfigTLS)) }
  def tls; end

  sig { returns(T::Hash[String, String]) }
  def grpc_meta; end

  sig do
    params(
      address: T.nilable(String),
      namespace: T.nilable(String),
      api_key: T.nilable(String),
      tls: T.nilable(Temporalio::EnvConfig::ClientConfigTLS),
      grpc_meta: T::Hash[String, String]
    ).void
  end
  def initialize(
    address: T.unsafe(nil),
    namespace: T.unsafe(nil),
    api_key: T.unsafe(nil),
    tls: T.unsafe(nil),
    grpc_meta: T.unsafe(nil)
  ); end

  sig { params(hash: T::Hash[Symbol, Object]).returns(Temporalio::EnvConfig::ClientConfigProfile) }
  def self.from_h(hash); end

  sig do
    params(
      profile: T.nilable(String),
      config_source: T.nilable(T.any(Pathname, String)),
      disable_file: T::Boolean,
      disable_env: T::Boolean,
      config_file_strict: T::Boolean,
      override_env_vars: T.nilable(T::Hash[String, String])
    ).returns(Temporalio::EnvConfig::ClientConfigProfile)
  end
  def self.load(
    profile: T.unsafe(nil),
    config_source: T.unsafe(nil),
    disable_file: T.unsafe(nil),
    disable_env: T.unsafe(nil),
    config_file_strict: T.unsafe(nil),
    override_env_vars: T.unsafe(nil)
  ); end

  sig { returns(T::Hash[Symbol, Object]) }
  def to_h; end

  sig { returns([T::Array[T.nilable(String)], T::Hash[Symbol, Object]]) }
  def to_client_connect_options; end
end

class Temporalio::EnvConfig::ClientConfig < ::Data
  extend T::Sig

  sig { returns(T::Hash[String, Temporalio::EnvConfig::ClientConfigProfile]) }
  def profiles; end

  sig { params(profiles: T::Hash[String, Temporalio::EnvConfig::ClientConfigProfile]).void }
  def initialize(profiles: T.unsafe(nil)); end

  sig { params(hash: T::Hash[String, T::Hash[Symbol, Object]]).returns(Temporalio::EnvConfig::ClientConfig) }
  def self.from_h(hash); end

  sig do
    params(
      config_source: T.nilable(T.any(Pathname, String)),
      config_file_strict: T::Boolean,
      override_env_vars: T.nilable(T::Hash[String, String])
    ).returns(Temporalio::EnvConfig::ClientConfig)
  end
  def self.load(config_source: T.unsafe(nil), config_file_strict: T.unsafe(nil), override_env_vars: T.unsafe(nil)); end

  sig do
    params(
      profile: T.nilable(String),
      config_source: T.nilable(T.any(Pathname, String)),
      disable_file: T::Boolean,
      disable_env: T::Boolean,
      config_file_strict: T::Boolean,
      override_env_vars: T.nilable(T::Hash[String, String])
    ).returns([T::Array[T.nilable(String)], T::Hash[Symbol, Object]])
  end
  def self.load_client_connect_options(
    profile: T.unsafe(nil),
    config_source: T.unsafe(nil),
    disable_file: T.unsafe(nil),
    disable_env: T.unsafe(nil),
    config_file_strict: T.unsafe(nil),
    override_env_vars: T.unsafe(nil)
  ); end

  sig { override(allow_incompatible: true).returns(T::Hash[String, T::Hash[Symbol, Object]]) }
  def to_h; end
end
