require 'temporalio/bridge'
require 'temporalio/bridge/connect_options'
require 'temporalio/bridge/tls_options'
require 'temporalio/connection/tls_options'
require 'temporalio/connection/test_service'
require 'temporalio/connection/workflow_service'
require 'temporalio/errors'
require 'temporalio/runtime'
require 'uri'

module Temporalio
  # A connection to the Temporal server. It provides gRPC level communication to a Temporal server.
  #
  # Connections are usually used through either {Temporalio::Client} or a {Temporalio::Worker}.
  # It may also be used to perform gRPC requests to the server (see {#workflow_service}).
  class Connection
    # @api private
    attr_reader :core_connection

    # @param address [String | nil] `host[:port]` for the Temporal server. Host defaults to `localhost:7233`.
    # @param [Temporalio::Connection::TlsOptions | nil] tls
    # @param [String | nil] identity
    # @param [Hash | nil] metadata
    def initialize(
      address = nil,
      tls: nil,
      identity: nil,
      metadata: nil,
      retry_config: nil
    )
      host, port = parse_url(address)

      runtime = Temporalio::Runtime.instance

      @core_connection = Temporalio::Bridge::Connection.connect(
        runtime.core_runtime,
        Temporalio::Bridge::ConnectOptions.new(
          url: tls ? "https://#{host}:#{port}" : "http://#{host}:#{port}",
          tls: tls && Temporalio::Bridge::TlsOptions.new(
            server_root_ca_cert: tls.server_root_ca_cert,
            client_cert: tls.client_cert,
            client_private_key: tls.client_private_key,
            server_name_override: tls.server_name_override,
          ),
          identity: identity || default_identity,
          metadata: metadata,
          retry_config: retry_config && Temporalio::Bridge::RetryConfig.new(
            initial_interval_millis: retry_config.initial_interval_millis,
            randomization_factor: retry_config.randomization_factor,
            multiplier: retry_config.multiplier,
            max_interval_millis: retry_config.max_interval_millis,
            max_elapsed_time_millis: retry_config.max_elapsed_time_millis,
            max_retries: retry_config.max_retries,
          ),
          client_version: Temporalio::VERSION,
        ),
      )
    end

    # Get an object for making WorkflowService RPCs.
    #
    # @return [Temporalio::Connection::WorkflowService]
    def workflow_service
      @workflow_service ||= Temporalio::Connection::WorkflowService.new(core_connection)
    end

    # Get an object for making TestService RPCs.
    #
    # @return [Temporalio::Connection::TestService]
    def test_service
      @test_service ||= Temporalio::Connection::TestService.new(core_connection)
    end

    private

    def parse_url(url)
      url ||= 'localhost:7233'

      # Turn this into a valid URI before parsing
      uri = URI.parse(url.include?('://') ? url : "//#{url}")
      raise Temporalio::Error, 'Target host as URL with scheme are not supported' if uri.scheme

      [uri.host || 'localhost', uri.port || 7233]
    end

    def default_identity
      "#{Process.pid}@#{Socket.gethostname}"
    end
  end
end
