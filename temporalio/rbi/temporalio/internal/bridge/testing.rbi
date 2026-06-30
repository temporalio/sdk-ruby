# typed: true

module Temporalio::Internal::Bridge::Testing; end

class Temporalio::Internal::Bridge::Testing::EphemeralServer
  extend T::Sig

  sig do
    params(
      runtime: Temporalio::Internal::Bridge::Runtime,
      options: Temporalio::Internal::Bridge::Testing::EphemeralServer::StartDevServerOptions
    ).returns(Temporalio::Internal::Bridge::Testing::EphemeralServer)
  end
  def self.start_dev_server(runtime, options); end

  sig do
    params(
      runtime: Temporalio::Internal::Bridge::Runtime,
      options: Temporalio::Internal::Bridge::Testing::EphemeralServer::StartTestServerOptions
    ).returns(Temporalio::Internal::Bridge::Testing::EphemeralServer)
  end
  def self.start_test_server(runtime, options); end

  sig { void }
  def shutdown; end

  sig do
    params(
      runtime: Temporalio::Internal::Bridge::Runtime,
      options: Temporalio::Internal::Bridge::Testing::EphemeralServer::StartDevServerOptions,
      queue: Queue
    ).void
  end
  def self.async_start_dev_server(runtime, options, queue); end

  sig do
    params(
      runtime: Temporalio::Internal::Bridge::Runtime,
      options: Temporalio::Internal::Bridge::Testing::EphemeralServer::StartTestServerOptions,
      queue: Queue
    ).void
  end
  def self.async_start_test_server(runtime, options, queue); end

  sig { returns(String) }
  def target; end

  sig { params(queue: Queue).void }
  def async_shutdown(queue); end
end

class Temporalio::Internal::Bridge::Testing::EphemeralServer::StartDevServerOptions < ::Struct
  extend T::Sig

  sig do
    params(
      existing_path: T.nilable(String),
      sdk_name: String,
      sdk_version: String,
      download_version: String,
      download_dest_dir: T.nilable(String),
      namespace: String,
      ip: String,
      port: T.nilable(Integer),
      database_filename: T.nilable(String),
      ui: T::Boolean,
      ui_port: T.nilable(Integer),
      log_format: String,
      log_level: String,
      extra_args: T::Array[String],
      download_ttl: T.nilable(T.any(Integer, Float))
    ).void
  end
  def initialize(
    existing_path,
    sdk_name,
    sdk_version,
    download_version,
    download_dest_dir,
    namespace,
    ip,
    port,
    database_filename,
    ui,
    ui_port,
    log_format,
    log_level,
    extra_args,
    download_ttl
  ); end
end

class Temporalio::Internal::Bridge::Testing::EphemeralServer::StartTestServerOptions < ::Struct
  extend T::Sig

  sig do
    params(
      existing_path: T.nilable(String),
      sdk_name: String,
      sdk_version: String,
      download_version: String,
      download_dest_dir: T.nilable(String),
      port: T.nilable(Integer),
      extra_args: T::Array[String],
      download_ttl: T.nilable(T.any(Integer, Float))
    ).void
  end
  def initialize(existing_path, sdk_name, sdk_version, download_version, download_dest_dir, port, extra_args, download_ttl); end
end
