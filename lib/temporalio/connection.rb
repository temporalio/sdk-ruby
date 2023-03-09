require 'temporalio/bridge'
require 'temporalio/bridge/connect_options'
require 'temporalio/bridge/tls_options'
require 'temporalio/connection/test_service'
require 'temporalio/connection/workflow_service'
require 'temporalio/errors'
require 'temporalio/runtime'
require 'uri'

module Temporalio
  # A connection to the Temporal server.
  #
  # This is used to instantiate a {Temporalio::Client}. But it also can be used for a direct
  # interaction with the API via one of the services (e.g. {#workflow_service}).
  class Connection
    # @api private
    attr_reader :core_connection

    public
    # @param address [String | nil] `host[:port]` for the Temporal server. Host defaults to `localhost:7233`.
    # @param [TlsOptions | nil] tls
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
            client_cert_key: tls.client_cert_key,
            server_name_override: tls.server_name_override,
          ),
          identity: identity || self.class.default_identity,
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

    def self.default_identity
      "#{Process.pid}@#{Socket.gethostname}"
    end

    class TlsOptions
      # Root CA certificate used by the server.
      # If not set, and the server's cert is issued by someone the operating system trusts,
      # verification will still work (ex: Cloud offering).
      attr_reader :server_root_ca_cert

      # Client certificate used to authenticate with the server.
      attr_reader :client_cert

      # Client private key used to authenticate with the server.
      attr_reader :client_cert_key

      # Overrides the target name used for SSL host name checking. If this attribute is not specified, the name used for
      # SSL host name checking will be the host part of the connection target address. This _should_ be used for testing
      # only.
      attr_reader :server_name_override

      # @param [String] server_root_ca_cert Root CA certificate used by the server. If not set, and the server's
      #   cert is issued by someone the operating system trusts, verification will still work (ex: Cloud offering).
      # @param [String] client_cert
      # @param [String] client_cert_key
      # @param [String] server_name_override
      def initialize(
        server_root_ca_cert: nil,
        client_cert: nil,
        client_cert_key: nil,
        server_name_override: nil
      )
        @server_root_ca_cert = server_root_ca_cert
        @client_cert = client_cert
        @client_cert_key = client_cert_key
        @server_name_override = server_name_override
      end
    end

    class RetryConfig
      # Initial backoff interval.
      # @default 100
      attr_reader :initial_interval_millis

      # Randomization jitter to add.
      # @default 0.2
      attr_reader :randomization_factor

      # Backoff multiplier.
      # @default 1.5
      attr_reader :multiplier

      # Maximum backoff interval.
      # @default 5000
      attr_reader :max_interval_millis

      # Maximum total time (optional).
      attr_reader :max_elapsed_time_millis

      # Maximum number of retries.
      # @default 10
      attr_reader :max_retries

      def initialize(
        initial_interval_millis: nil,
        randomization_factor: nil,
        multiplier: nil,
        max_interval_millis: nil,
        max_elapsed_time_millis: nil,
        max_retries: nil
      )
        @initial_interval_millis = initial_interval_millis || 100
        @randomization_factor = randomization_factor || 0.2
        @multiplier = multiplier || 1.5
        @max_interval_millis = max_interval_millis || 5_000
        @max_elapsed_time_millis = max_elapsed_time_millis
        @max_retries = max_retries || 10
      end
    end
  end
end
