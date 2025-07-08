# frozen_string_literal: true

require 'delegate'
require 'temporalio/api'
require 'temporalio/api/testservice/v1/request_response'
require 'temporalio/client'
require 'temporalio/client/connection/test_service'
require 'temporalio/client/workflow_handle'
require 'temporalio/converters'
require 'temporalio/internal/bridge/testing'
require 'temporalio/internal/proto_utils'
require 'temporalio/runtime'
require 'temporalio/search_attributes'
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
      # @param logger [Logger] Logger for the client.
      # @param default_workflow_query_reject_condition [WorkflowQueryRejectCondition, nil] Default rejection condition
      #   for the client.
      # @param ip [String] IP to bind to.
      # @param port [Integer, nil] Port to bind on, or `nil` for random.
      # @param ui [Boolean] If +true+, also starts the UI.
      # @param ui_port [Integer, nil] Port to bind on if `ui` is true, or `nil` for random.
      # @param search_attributes [Array<SearchAttributes::Key>] Search attributes to make available on start.
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
      # @param dev_server_download_ttl [Float, nil] How long the automatic download should be cached for. If nil, cached
      #   indefinitely.
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
        logger: Logger.new($stdout, level: Logger::WARN),
        default_workflow_query_reject_condition: nil,
        ip: '127.0.0.1',
        port: nil,
        ui: false, # rubocop:disable Naming/MethodParameterName
        ui_port: nil,
        search_attributes: [],
        runtime: Runtime.default,
        dev_server_existing_path: nil,
        dev_server_database_filename: nil,
        dev_server_log_format: 'pretty',
        dev_server_log_level: 'warn',
        dev_server_download_version: 'default',
        dev_server_download_dest_dir: nil,
        dev_server_extra_args: [],
        dev_server_download_ttl: nil,
        &
      )
        # Add search attribute args
        unless search_attributes.empty?
          dev_server_extra_args += search_attributes.flat_map do |key|
            raise 'Search attribute must be Key' unless key.is_a?(SearchAttributes::Key)

            ['--search-attribute', "#{key.name}=#{SearchAttributes::IndexedValueType::PROTO_NAMES[key.type]}"]
          end
        end

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
          ui_port: ui ? ui_port : nil,
          log_format: dev_server_log_format,
          log_level: dev_server_log_level,
          extra_args: dev_server_extra_args,
          download_ttl: dev_server_download_ttl
        )
        _with_core_server(
          core_server: Internal::Bridge::Testing::EphemeralServer.start_dev_server(
            runtime._core_runtime, server_options
          ),
          namespace:,
          data_converter:,
          interceptors:,
          logger:,
          default_workflow_query_reject_condition:,
          runtime:,
          supports_time_skipping: false,
          & # steep:ignore
        )
      end

      # Start a time-skipping test server. This server can skip time but may not have all of the Temporal features of
      # the {start_local} form. By default, the server is downloaded to tmp if not already present. The test server is
      # run as a child process. All options that start with +test_server_+ are for this specific implementation and
      # therefore are not stable and may be changed as the underlying implementation changes.
      #
      # If a block is given it is passed the environment and the environment is shut down after. If a block is not
      # given, the environment is returned and {shutdown} needs to be called manually.
      #
      # @param data_converter [Converters::DataConverter] Data converter for the client.
      # @param interceptors [Array<Client::Interceptor>] Interceptors for the client.
      # @param logger [Logger] Logger for the client.
      # @param default_workflow_query_reject_condition [WorkflowQueryRejectCondition, nil] Default rejection condition
      #   for the client.
      # @param port [Integer, nil] Port to bind on, or +nil+ for random.
      # @param runtime [Runtime] Runtime for the server and client.
      # @param test_server_existing_path [String, nil] Existing CLI path to use instead of downloading and caching to
      #   tmp.
      # @param test_server_download_version [String] Version of test server to download and cache.
      # @param test_server_download_dest_dir [String, nil] Where to download. Defaults to tmp.
      # @param test_server_extra_args [Array<String>] Any extra arguments for the test server.
      # @param test_server_download_ttl [Float, nil] How long the automatic download should be cached for. If nil,
      #   cached indefinitely.
      #
      # @yield [environment] If a block is given, it is called with the environment and upon complete the environment is
      #   shutdown.
      # @yieldparam environment [WorkflowEnvironment] Environment that is shut down upon block completion.
      #
      # @return [WorkflowEnvironment, Object] Started local server environment with client if there was no block given,
      #   or block result if block was given.
      def self.start_time_skipping(
        data_converter: Converters::DataConverter.default,
        interceptors: [],
        logger: Logger.new($stdout, level: Logger::WARN),
        default_workflow_query_reject_condition: nil,
        port: nil,
        runtime: Runtime.default,
        test_server_existing_path: nil,
        test_server_download_version: 'default',
        test_server_download_dest_dir: nil,
        test_server_extra_args: [],
        test_server_download_ttl: nil,
        &
      )
        server_options = Internal::Bridge::Testing::EphemeralServer::StartTestServerOptions.new(
          existing_path: test_server_existing_path,
          sdk_name: 'sdk-ruby',
          sdk_version: VERSION,
          download_version: test_server_download_version,
          download_dest_dir: test_server_download_dest_dir,
          port:,
          extra_args: test_server_extra_args,
          download_ttl: test_server_download_ttl
        )
        _with_core_server(
          core_server: Internal::Bridge::Testing::EphemeralServer.start_test_server(
            runtime._core_runtime, server_options
          ),
          namespace: 'default',
          data_converter:,
          interceptors:,
          logger:,
          default_workflow_query_reject_condition:,
          runtime:,
          supports_time_skipping: true,
          & # steep:ignore
        )
      end

      # @!visibility private
      def self._with_core_server(
        core_server:,
        namespace:,
        data_converter:,
        interceptors:,
        logger:,
        default_workflow_query_reject_condition:,
        runtime:,
        supports_time_skipping:
      )
        # Try to connect, shutdown if we can't
        begin
          client = Client.connect(
            core_server.target,
            namespace,
            data_converter:,
            interceptors:,
            logger:,
            default_workflow_query_reject_condition:,
            runtime:
          )
          server = Ephemeral.new(client, core_server, supports_time_skipping:)
        rescue Exception # rubocop:disable Lint/RescueException
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

      # @return [Boolean] Whether this environment supports time skipping.
      def supports_time_skipping?
        false
      end

      # Advanced time.
      #
      # If this server supports time skipping, this will immediately advance time and return. If it does not, this is
      # a standard {::sleep}.
      #
      # @param duration [Float] Duration seconds.
      def sleep(duration)
        Kernel.sleep(duration)
      end

      # Current time of the environment.
      #
      # If this server supports time skipping, this will be the current time as known to the environment. If it does
      # not, this is a standard {::Time.now}.
      #
      # @return [Time] Current time.
      def current_time
        Time.now
      end

      # Run a block with automatic time skipping disabled. This just runs the block for environments that don't support
      # time skipping.
      #
      # @yield Block to run.
      # @return [Object] Result of the block.
      def auto_time_skipping_disabled(&)
        raise 'Block required' unless block_given?

        yield
      end

      # @!visibility private
      class Ephemeral < WorkflowEnvironment
        def initialize(client, core_server, supports_time_skipping:)
          # Add our interceptor at the end of the existing interceptors that skips time
          client_options = client.options.with(
            interceptors: client.options.interceptors + [TimeSkippingClientInterceptor.new(self)]
          )
          client = Client.new(**client_options.to_h) # steep:ignore
          super(client)

          @auto_time_skipping = true
          @core_server = core_server
          @test_service = Client::Connection::TestService.new(client.connection) if supports_time_skipping
        end

        # @!visibility private
        def shutdown
          @core_server.shutdown
        end

        # @!visibility private
        def supports_time_skipping?
          !@test_service.nil?
        end

        # @!visibility private
        def sleep(duration)
          return super unless supports_time_skipping?

          @test_service.unlock_time_skipping_with_sleep(
            Api::TestService::V1::SleepRequest.new(duration: Internal::ProtoUtils.seconds_to_duration(duration))
          )
        end

        # @!visibility private
        def current_time
          return super unless supports_time_skipping?

          resp = @test_service.get_current_time(Google::Protobuf::Empty.new)
          Internal::ProtoUtils.timestamp_to_time(resp.time) or raise 'Time missing'
        end

        # @!visibility private
        def auto_time_skipping_disabled(&)
          raise 'Block required' unless block_given?
          return super unless supports_time_skipping?

          already_disabled = !@auto_time_skipping
          @auto_time_skipping = false
          begin
            yield
          ensure
            @auto_time_skipping = true unless already_disabled
          end
        end

        # @!visibility private
        def time_skipping_unlocked(&)
          # If disabled or unsupported, no locking/unlocking, just run and return
          return yield if !supports_time_skipping? || !@auto_time_skipping

          # Unlock to start time skipping, lock again to stop it
          @test_service.unlock_time_skipping(Api::TestService::V1::UnlockTimeSkippingRequest.new)
          user_code_success = false
          begin
            result = yield
            user_code_success = true
            result
          ensure
            # Lock it back
            begin
              @test_service.lock_time_skipping(Api::TestService::V1::LockTimeSkippingRequest.new)
            rescue StandardError => e
              # Re-raise if user code succeeded, otherwise swallow
              raise if user_code_success

              client.options.logger.error('Failed locking time skipping after error')
              client.options.logger.error(e)
            end
          end
        end
      end

      private_constant :Ephemeral

      # @!visibility private
      class TimeSkippingClientInterceptor
        include Client::Interceptor

        def initialize(env)
          @env = env
        end

        # @!visibility private
        def intercept_client(next_interceptor)
          Outbound.new(next_interceptor, @env)
        end

        # @!visibility private
        class Outbound < Client::Interceptor::Outbound
          def initialize(next_interceptor, env)
            super(next_interceptor)
            @env = env
          end

          # @!visibility private
          def start_workflow(input)
            TimeSkippingWorkflowHandle.new(super, @env)
          end
        end

        # @!visibility private
        class TimeSkippingWorkflowHandle < SimpleDelegator
          def initialize(handle, env)
            super(handle) # steep:ignore
            @env = env
          end

          # @!visibility private
          def result(follow_runs: true, result_hint: nil, rpc_options: nil)
            @env.time_skipping_unlocked { super(follow_runs:, result_hint:, rpc_options:) }
          end
        end
      end

      private_constant :TimeSkippingClientInterceptor
    end
  end
end
