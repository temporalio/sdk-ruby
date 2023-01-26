require 'google/protobuf/well_known_types'
require 'temporalio/client'
require 'temporalio/testing/time_skipping_interceptor'

module Temporalio
  module Testing
    # Workflow environment for testing workflows.
    #
    # Most developers will want to use the {Temporalio::Testing.start_time_skipping_environment} to
    # start a test server process that automatically skips time as needed. Alternatively,
    # {Temporalio::Testing.start_local_environment} may be used for a full, local Temporal server
    # with more features.
    #
    # @note Unless using the above mentioned methods with an explicit block, you will need to call
    # {#shutdown} after you're finished with this environment.
    class WorkflowEnvironment
      # @return [Temporalio::Connection] A connection to this environment.
      attr_reader :connection

      # @return [String] A namespace for this environment.
      attr_reader :namespace

      # @api private
      def initialize(server, connection, namespace)
        @server = server
        @connection = connection
        @namespace = namespace
      end

      # A default client to be used with this environment.
      #
      # @return [Temporalio::Client] A default client.
      def client
        @client ||= begin
          # TODO: Add a workflow interceptor for interpreting assertion error
          interceptors = [TimeSkippingInterceptor.new(self)]
          Temporalio::Client.new(connection, namespace, interceptors: interceptors)
        end
      end

      # Sleep in this environment.
      #
      # This awaits a regular {Kernel.sleep} in regular environments, or manually skips time in
      # time-skipping environments.
      #
      # @param duration [Integer] Amount of time to sleep.
      def sleep(duration)
        return Kernel.sleep(duration) unless supports_time_skipping?

        request = Temporalio::Api::TestService::V1::SleepRequest.new(
          duration: Google::Protobuf::Duration.new(seconds: duration),
        )
        connection.test_service.unlock_time_skipping_with_sleep(request)

        nil
      end

      # Get the current time known to this environment.
      #
      # For non-time-skipping environments this is simply the system time. For time-skipping
      # environments this is whatever time has been skipped to.
      #
      # @return [Time]
      def current_time
        return Time.now unless supports_time_skipping?

        connection.test_service.get_current_time&.time&.to_time
      end

      # Whether this environment supports time skipping.
      #
      # @return [Boolean]
      def supports_time_skipping?
        server.has_test_service?
      end

      # Shut down this environment.
      def shutdown
        server.shutdown
      end

      # Unlock time skipping.
      #
      # This will have no effect in an environment that does not support time-skipping (e.g.
      # Temporalite).
      #
      # @yield A block to be called once time skipping has been unlocked.
      #
      # @return [any] The return value of the block.
      def with_time_skipping
        return yield unless supports_time_skipping?

        begin
          # Unlock to start time skipping, lock again to stop it
          connection.test_service.unlock_time_skipping(
            Temporalio::Api::TestService::V1::UnlockTimeSkippingRequest.new,
          )

          yield
        ensure
          connection.test_service.lock_time_skipping(
            Temporalio::Api::TestService::V1::LockTimeSkippingRequest.new,
          )
        end
      end

      private

      attr_reader :server
    end
  end
end
