require 'temporal/api/testservice/v1/request_response_pb'
require 'temporalio/connection/service'

module Temporalio
  class Connection
    # A class for making TestService RPCs
    #
    # This is normally accessed via {Temoralio::Connection#test_service}.
    class TestService < Service
      # @api private
      def initialize(core_connection)
        super(core_connection, :test_service)
      end

      # @param request [Temporalio::Api::TestService::V1::LockTimeSkippingRequest]
      # @param metadata [Hash<String, String>] Headers used on the RPC call.
      #   Keys here override client-level RPC metadata keys.
      # @param timeout [Integer] Optional RPC deadline to set for each RPC call.
      #
      # @return [Temporalio::Api::TestService::V1::LockTimeSkippingResponse]
      def lock_time_skipping(request, metadata: {}, timeout: nil)
        encoded = Temporalio::Api::TestService::V1::LockTimeSkippingRequest.encode(request)
        response = call(:lock_time_skipping, encoded, metadata, timeout)

        Temporalio::Api::TestService::V1::LockTimeSkippingResponse.decode(response)
      end

      # @param request [Temporalio::Api::TestService::V1::UnlockTimeSkippingRequest]
      # @param metadata [Hash<String, String>] Headers used on the RPC call.
      #   Keys here override client-level RPC metadata keys.
      # @param timeout [Integer] Optional RPC deadline to set for each RPC call.
      #
      # @return [Temporalio::Api::TestService::V1::UnlockTimeSkippingResponse]
      def unlock_time_skipping(request, metadata: {}, timeout: nil)
        encoded = Temporalio::Api::TestService::V1::UnlockTimeSkippingRequest.encode(request)
        response = call(:unlock_time_skipping, encoded, metadata, timeout)

        Temporalio::Api::TestService::V1::UnlockTimeSkippingResponse.decode(response)
      end

      # @param request [Temporalio::Api::TestService::V1::SleepRequest]
      # @param metadata [Hash<String, String>] Headers used on the RPC call.
      #   Keys here override client-level RPC metadata keys.
      # @param timeout [Integer] Optional RPC deadline to set for each RPC call.
      #
      # @return [Temporalio::Api::TestService::V1::SleepResponse]
      def sleep(request, metadata: {}, timeout: nil)
        encoded = Temporalio::Api::TestService::V1::SleepRequest.encode(request)
        response = call(:sleep, encoded, metadata, timeout)

        Temporalio::Api::TestService::V1::SleepResponse.decode(response)
      end

      # @param request [Temporalio::Api::TestService::V1::SleepUntilRequest]
      # @param metadata [Hash<String, String>] Headers used on the RPC call.
      #   Keys here override client-level RPC metadata keys.
      # @param timeout [Integer] Optional RPC deadline to set for each RPC call.
      #
      # @return [Temporalio::Api::TestService::V1::SleepResponse]
      def sleep_until(request, metadata: {}, timeout: nil)
        encoded = Temporalio::Api::TestService::V1::SleepUntilRequest.encode(request)
        response = call(:sleep_until, encoded, metadata, timeout)

        Temporalio::Api::TestService::V1::SleepResponse.decode(response)
      end

      # @param request [Temporalio::Api::TestService::V1::SleepRequest]
      # @param metadata [Hash<String, String>] Headers used on the RPC call.
      #   Keys here override client-level RPC metadata keys.
      # @param timeout [Integer] Optional RPC deadline to set for each RPC call.
      #
      # @return [Temporalio::Api::TestService::V1::SleepResponse]
      def unlock_time_skipping_with_sleep(request, metadata: {}, timeout: nil)
        encoded = Temporalio::Api::TestService::V1::SleepRequest.encode(request)
        response = call(:unlock_time_skipping_with_sleep, encoded, metadata, timeout)

        Temporalio::Api::TestService::V1::SleepResponse.decode(response)
      end

      # @param metadata [Hash<String, String>] Headers used on the RPC call.
      #   Keys here override client-level RPC metadata keys.
      # @param timeout [Integer] Optional RPC deadline to set for each RPC call.
      #
      # @return [Temporalio::Api::TestService::V1::GetCurrentTimeResponse]
      def get_current_time(metadata: {}, timeout: nil)
        response = call(:get_current_time, '', metadata, timeout)

        Temporalio::Api::TestService::V1::GetCurrentTimeResponse.decode(response)
      end
    end
  end
end
