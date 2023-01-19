require 'temporalio/bridge'
require 'temporalio/connection'
require 'temporalio/runtime'
require 'temporalio/testing/workflow_environment'
require 'temporalio/version'

module Temporalio
  module Testing
    class << self
      # Start a full Temporal server locally, downloading if necessary.
      #
      # This environment is good for testing full server capabilities, but does not support time
      # skipping like {.start_time_skipping} does.
      # {Temporalio::Testing::WorkflowEnvironment#supports_time_skipping} will always return `false`
      # for this environment. {Temporalio::Testing::WorkflowEnvironment#sleep} will sleep the actual
      # amount of time and {Temporalio::Testing::WorkflowEnvironment#get_current_time}` will return
      # the current time.
      #
      # Internally, this uses [Temporalite](https://github.com/temporalio/temporalite). Which is a
      # self-contained binary for Temporal using Sqlite persistence. This will download Temporalite
      # to a temporary directory by default if it has not already been downloaded before and
      # `:existing_path` is not set.
      #
      # In the future, the Temporalite implementation may be changed to another implementation.
      # Therefore, all `temporalite_` prefixed parameters are Temporalite specific and may not apply
      # to newer versions.
      #
      # @param namespace [String] Namespace name to use for this environment.
      # @param ip [String] IP address to bind to, or 127.0.0.1 by default.
      # @param port [Integer] Port number to bind to, or an OS-provided port by default.
      # @param download_dir [String] Directory to download binary to if a download is needed. If
      #   unset, this is the system's temporary directory.
      # @param ui [Boolean] If `true`, will start a UI in Temporalite.
      # @param temporalite_existing_path [String] Existing path to the Temporalite binary. If
      #   present, no download will be attempted to fetch the binary.
      # @param temporalite_database_filename [String] Path to the Sqlite database to use for
      #   Temporalite. Unset default means only in-memory Sqlite will be used.
      # @param temporalite_log_format [String] Log format for Temporalite.
      # @param temporalite_log_level [String] Log level to use for Temporalite.
      # @param temporalite_download_version [String] Specific Temporalite version to download.
      #   Defaults to `default` which downloads the version known to work best with this SDK.
      # @param temporalite_extra_args [Array<String>] Extra arguments for the Temporalite binary.
      #
      # @yield Optionally you can provide a block which will ensure that the environment has been
      #   shut down after. The newly created {Temporalio::Testing::WorkflowEnvironment} will be
      #   passed into the block as a single argument. Alternatively you will need to call
      #   {Temporalio::Testing::WorkflowEnvironment#shutdown} explicitly after you're done with it.
      #
      # @return [Temporalio::Testing::WorkflowEnvironment] The newly started Temporalite workflow
      #   environment.
      def start_local_environment(
        namespace: 'default',
        ip: '127.0.0.1',
        port: nil,
        download_dir: nil,
        ui: false,
        temporalite_existing_path: nil,
        temporalite_database_filename: nil,
        temporalite_log_format: 'pretty',
        temporalite_log_level: 'warn',
        temporalite_download_version: 'default',
        temporalite_extra_args: [],
        &block
      )
        # TODO: Sync with the SDK's logger level when implemented
        runtime = Temporalio::Runtime.instance
        server = Temporalio::Bridge::TestServer.start_temporalite(
          runtime.core_runtime,
          temporalite_existing_path,
          'sdk-ruby',
          Temporalio::VERSION,
          temporalite_download_version,
          download_dir,
          namespace,
          ip,
          port,
          temporalite_database_filename,
          ui,
          temporalite_log_format,
          temporalite_log_level,
          temporalite_extra_args,
        )
        env = init_workflow_environment_for(server)

        return env unless block

        run_server(server, env, &block)
      end

      # Start a time skipping workflow environment.
      #
      # Time can be manually skipped forward using {Temporalio::Testing::WorkflowEnvironment#sleep}.
      # The currently known time can be obtained via
      # {Temporalio::Testing::WorkflowEnvironment#get_current_time}.
      #
      # @note Auto time skipping is not yet implemented.
      #
      # Internally, this environment lazily downloads a test-server binary for the current OS/arch
      # into the temp directory if it is not already there. Then the executable is started and will
      # be killed when {Temporalio::Testing::WorkflowEnvironment#shutdown} is called (which is
      # implicitly done if a block is provided to this method).
      #
      # Users can reuse this environment for testing multiple independent workflows, but not
      # concurrently. Time skipping, which is automatically done when awaiting a workflow result
      # (pending implementation) and manually done on
      # {Temporalio::Testing::WorkflowEnvironment#sleep}, is global to the environment, not to the
      # workflow under test.
      #
      # In the future, the test server implementation may be changed to another implementation.
      # Therefore, all `test_server_` prefixed parameters are test server specific and may not apply
      # to newer versions.
      #
      # @param port [Integer] Port number to bind to, or an OS-provided port by default.
      # @param download_dir [String] Directory to download binary to if a download is needed.
      #   If unset, this is the system's temporary directory.
      # @param test_server_existing_path [String] Existing path to the test server binary. If
      #   present, no download will be attempted to fetch the binary.
      # @param test_server_download_version [String] Specific test server version to download.
      #   Defaults to `default` which downloads the version known to work best with this SDK.
      # @param test_server_extra_args [Array<String>] Extra arguments for the test server binary.
      #
      # @yield Optionally you can provide a block which will ensure that the environment has been
      #   shut down after. The newly created {Temporalio::Testing::WorkflowEnvironment} will be
      #   passed into the block as a single argument. Alternatively you will need to call
      #   {Temporalio::Testing::WorkflowEnvironment#shutdown} explicitly after you're done with it.
      #
      # @return [Temporalio::Testing::WorkflowEnvironment] The newly started TestServer workflow
      #   environment.
      def start_time_skipping_environment(
        port: nil,
        download_dir: nil,
        test_server_existing_path: nil,
        test_server_download_version: 'default',
        test_server_extra_args: [],
        &block
      )
        # TODO: Use interceptors to inject a time skipping WorkflowHandle.
        runtime = Temporalio::Runtime.instance
        server = Temporalio::Bridge::TestServer.start(
          runtime.core_runtime,
          test_server_existing_path,
          'sdk-ruby',
          Temporalio::VERSION,
          test_server_download_version,
          download_dir,
          port,
          test_server_extra_args,
        )
        env = init_workflow_environment_for(server)

        return env unless block

        run_server(server, env, &block)
      end

      private

      def init_workflow_environment_for(server)
        connection = Temporalio::Connection.new(server.target)
        Temporalio::Testing::WorkflowEnvironment.new(server, connection)
      rescue Temporalio::Bridge::Error # Shutdown if unable to connect to the server
        server.shutdown
        raise
      end

      def run_server(server, env, &block)
        block.call(env)
      ensure
        server.shutdown
      end
    end
  end
end
