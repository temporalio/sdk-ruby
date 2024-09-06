# frozen_string_literal: true

require 'temporalio/client'
require 'temporalio/converters'
require 'temporalio/internal/bridge/testing'
require 'temporalio/runtime'
require 'temporalio/version'

module Temporalio
  module Testing
    # Test environment with a Temporal server for running workflows and more.
    class WorkflowEnvironment
      # @return [Client] Client for the server.
      attr_reader :client

      # Start a local dev server. This is a full Temporal dev server from the CLI that by default downloaded to tmp if
      # not already present. The dev server is run as a child process. All options that start with +dev_server_+ are for
      # this specific implementation and therefore are not stable and may be changed as the underlying implementation
      # changes.
      #
      # If a block is given it is passed the environment and the environment is shut down after. If a block is not
      # given, the environment is returned and {shutdown} needs to be called manually.
      #
      # @param namespace [String] Namespace for the server.
      # @param data_converter [Converters::DataConverter] Data converter for the client.
      # @param interceptors [Array<Client::Interceptor>] Interceptors for the client.
      # @param ip [String] IP to bind to.
      # @param port [Integer, nil] Port to bind on, or +nil+ for random.
      # @param ui [Boolean] If +true+, also starts the UI.
      # @param runtime [Runtime] Runtime for the server and client.
      # @param dev_server_existing_path [String, nil] Existing CLI path to use instead of downloading and caching to
      #   tmp.
      # @param dev_server_database_filename [String, nil] Persistent SQLite filename to use across local server runs.
      #   Default of +nil+ means in-memory only.
      # @param dev_server_log_format [String] Log format for CLI dev server.
      # @param dev_server_log_level [String] Log level for CLI dev server.
      # @param dev_server_download_version [String] Version of dev server to download and cache.
      # @param dev_server_download_dest_dir [String, nil] Where to download. Defaults to tmp.
      # @param dev_server_extra_args [Array<String>] Any extra arguments for the CLI dev server.
      #
      # @yield [environment] If a block is given, it is called with the environment and upon complete the environment is
      #   shutdown.
      # @yieldparam environment [WorkflowEnvironment] Environment that is shut down upon block completion.
      #
      # @return [WorkflowEnvironment, Object] Started local server environment with client if there was no block given,
      #   or block result if block was given.
      def self.start_local(
        namespace: 'default',
        data_converter: Converters::DataConverter.default,
        interceptors: [],
        # TODO(cretz): More client connect options
        ip: '127.0.0.1',
        port: nil,
        ui: false, # rubocop:disable Naming/MethodParameterName
        runtime: Runtime.default,
        dev_server_existing_path: nil,
        dev_server_database_filename: nil,
        dev_server_log_format: 'pretty',
        dev_server_log_level: 'warn',
        dev_server_download_version: 'default',
        dev_server_download_dest_dir: nil,
        dev_server_extra_args: []
      )
        server_options = Internal::Bridge::Testing::EphemeralServer::StartDevServerOptions.new(
          existing_path: dev_server_existing_path,
          sdk_name: 'sdk-ruby',
          sdk_version: VERSION,
          download_version: dev_server_download_version,
          download_dest_dir: dev_server_download_dest_dir,
          namespace:,
          ip:,
          port:,
          database_filename: dev_server_database_filename,
          ui:,
          log_format: dev_server_log_format,
          log_level: dev_server_log_level,
          extra_args: dev_server_extra_args
        )
        core_server = Internal::Bridge::Testing::EphemeralServer.start_dev_server(runtime._core_runtime, server_options)
        # Try to connect, shutdown if we can't
        begin
          client = Client.connect(
            core_server.target,
            namespace,
            data_converter:,
            interceptors:,
            runtime:
          )
          server = Ephemeral.new(client, core_server)
        rescue StandardError
          core_server.shutdown
          raise
        end
        if block_given?
          begin
            yield server
          ensure
            server.shutdown
          end
        else
          server
        end
      end

      # Create workflow environment to an existing server with the given client.
      #
      # @param client [Client] Client to existing server.
      def initialize(client)
        @client = client
      end

      # Shutdown this workflow environment.
      def shutdown
        # Do nothing by default
      end

      # @!visibility private
      class Ephemeral < WorkflowEnvironment
        def initialize(client, core_server)
          super(client)
          @core_server = core_server
        end

        # @!visibility private
        def shutdown
          @core_server.shutdown
        end
      end
    end
  end
end
