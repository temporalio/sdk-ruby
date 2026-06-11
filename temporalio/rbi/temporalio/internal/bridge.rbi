# typed: true

module Temporalio::Internal::Bridge
  extend T::Sig

  sig { void }
  def self.assert_fiber_compatibility!; end

  sig { returns(T::Boolean) }
  def self.fibers_supported; end
end

module Temporalio::Internal::Bridge::EnvConfig
  extend T::Sig

  sig do
    params(
      profile: T.nilable(String),
      path: T.nilable(String),
      data: T.nilable(String),
      disable_file: T::Boolean,
      disable_env: T::Boolean,
      config_file_strict: T::Boolean,
      override_env_vars: T.nilable(T::Hash[String, String])
    ).returns(T::Hash[Symbol, T.nilable(Object)])
  end
  def self.load_client_connect_config(profile, path, data, disable_file, disable_env, config_file_strict,
                                      override_env_vars); end

  sig do
    params(
      path: T.nilable(String),
      data: T.nilable(String),
      config_file_strict: T::Boolean,
      override_env_vars: T.nilable(T::Hash[String, String])
    ).returns(T::Hash[String, T::Hash[Symbol, T.nilable(Object)]])
  end
  def self.load_client_config(path, data, config_file_strict, override_env_vars); end
end

class Temporalio::Internal::Bridge::Error < StandardError
end
