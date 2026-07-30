# typed: true

class Temporalio::Testing::WorkflowEnvironment
  extend T::Sig

  sig { returns(Temporalio::Client) }
  attr_reader :client

  sig { params(client: Temporalio::Client).void }
  def initialize(client); end

  sig { void }
  def shutdown; end

  sig { returns(T::Boolean) }
  def supports_time_skipping?; end

  sig { params(duration: T.any(Integer, Float)).void }
  def sleep(duration); end

  sig { returns(Time) }
  def current_time; end

  sig { params(name: String, task_queue: String).returns(Temporalio::Api::Nexus::V1::Endpoint) }
  def create_nexus_endpoint(name:, task_queue:); end

  sig { params(endpoint: Temporalio::Api::Nexus::V1::Endpoint).returns(NilClass) }
  def delete_nexus_endpoint(endpoint); end

  sig { type_parameters(:T).params(block: T.proc.returns(T.type_parameter(:T))).returns(T.type_parameter(:T)) }
  def auto_time_skipping_disabled(&block); end

  class << self
    extend T::Sig

    sig do
      type_parameters(:T)
        .params(
          namespace: String,
          data_converter: Temporalio::Converters::DataConverter,
          interceptors: T::Array[Temporalio::Client::Interceptor],
          logger: Logger,
          default_workflow_query_reject_condition: T.nilable(Integer),
          ip: String,
          port: T.nilable(Integer),
          ui: T::Boolean,
          ui_port: T.nilable(Integer),
          search_attributes: T::Array[Temporalio::SearchAttributes::Key],
          runtime: Temporalio::Runtime,
          dev_server_existing_path: T.nilable(String),
          dev_server_database_filename: T.nilable(String),
          dev_server_log_format: String,
          dev_server_log_level: String,
          dev_server_download_version: String,
          dev_server_download_dest_dir: T.nilable(String),
          dev_server_extra_args: T::Array[String],
          dev_server_download_ttl: T.nilable(Float),
          block: T.nilable(T.proc.params(arg0: Temporalio::Testing::WorkflowEnvironment).returns(T.type_parameter(:T)))
        ).returns(T.any(Temporalio::Testing::WorkflowEnvironment, T.type_parameter(:T)))
    end
    def start_local(
      namespace: T.unsafe(nil),
      data_converter: T.unsafe(nil),
      interceptors: T.unsafe(nil),
      logger: T.unsafe(nil),
      default_workflow_query_reject_condition: T.unsafe(nil),
      ip: T.unsafe(nil),
      port: T.unsafe(nil),
      ui: T.unsafe(nil),
      ui_port: T.unsafe(nil),
      search_attributes: T.unsafe(nil),
      runtime: T.unsafe(nil),
      dev_server_existing_path: T.unsafe(nil),
      dev_server_database_filename: T.unsafe(nil),
      dev_server_log_format: T.unsafe(nil),
      dev_server_log_level: T.unsafe(nil),
      dev_server_download_version: T.unsafe(nil),
      dev_server_download_dest_dir: T.unsafe(nil),
      dev_server_extra_args: T.unsafe(nil),
      dev_server_download_ttl: T.unsafe(nil),
      &block
    ); end

    sig do
      type_parameters(:T)
        .params(
          data_converter: Temporalio::Converters::DataConverter,
          interceptors: T::Array[Temporalio::Client::Interceptor],
          logger: Logger,
          default_workflow_query_reject_condition: T.nilable(Integer),
          port: T.nilable(Integer),
          runtime: Temporalio::Runtime,
          test_server_existing_path: T.nilable(String),
          test_server_download_version: String,
          test_server_download_dest_dir: T.nilable(String),
          test_server_extra_args: T::Array[String],
          test_server_download_ttl: T.nilable(Float),
          block: T.nilable(T.proc.params(arg0: Temporalio::Testing::WorkflowEnvironment).returns(T.type_parameter(:T)))
        ).returns(T.any(Temporalio::Testing::WorkflowEnvironment, T.type_parameter(:T)))
    end
    def start_time_skipping(
      data_converter: T.unsafe(nil),
      interceptors: T.unsafe(nil),
      logger: T.unsafe(nil),
      default_workflow_query_reject_condition: T.unsafe(nil),
      port: T.unsafe(nil),
      runtime: T.unsafe(nil),
      test_server_existing_path: T.unsafe(nil),
      test_server_download_version: T.unsafe(nil),
      test_server_download_dest_dir: T.unsafe(nil),
      test_server_extra_args: T.unsafe(nil),
      test_server_download_ttl: T.unsafe(nil),
      &block
    ); end
  end
end
