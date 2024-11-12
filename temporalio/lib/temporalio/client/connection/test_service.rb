# frozen_string_literal: true

# Generated code.  DO NOT EDIT!

require 'temporalio/api'
require 'temporalio/client/connection/service'
require 'temporalio/internal/bridge/client'

module Temporalio
  class Client
    class Connection
      # TestService API.
      class TestService < Service
        # @!visibility private
        def initialize(connection)
          super(connection, Internal::Bridge::Client::SERVICE_TEST)
        end

        # Calls TestService.LockTimeSkipping API call.
        #
        # @param request [Temporalio::Api::TestService::V1::LockTimeSkippingRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::TestService::V1::LockTimeSkippingResponse] API response.
        def lock_time_skipping(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'lock_time_skipping',
            request_class: Temporalio::Api::TestService::V1::LockTimeSkippingRequest,
            response_class: Temporalio::Api::TestService::V1::LockTimeSkippingResponse,
            request:,
            rpc_options:
          )
        end

        # Calls TestService.UnlockTimeSkipping API call.
        #
        # @param request [Temporalio::Api::TestService::V1::UnlockTimeSkippingRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::TestService::V1::UnlockTimeSkippingResponse] API response.
        def unlock_time_skipping(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'unlock_time_skipping',
            request_class: Temporalio::Api::TestService::V1::UnlockTimeSkippingRequest,
            response_class: Temporalio::Api::TestService::V1::UnlockTimeSkippingResponse,
            request:,
            rpc_options:
          )
        end

        # Calls TestService.Sleep API call.
        #
        # @param request [Temporalio::Api::TestService::V1::SleepRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::TestService::V1::SleepResponse] API response.
        def sleep(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'sleep',
            request_class: Temporalio::Api::TestService::V1::SleepRequest,
            response_class: Temporalio::Api::TestService::V1::SleepResponse,
            request:,
            rpc_options:
          )
        end

        # Calls TestService.SleepUntil API call.
        #
        # @param request [Temporalio::Api::TestService::V1::SleepUntilRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::TestService::V1::SleepResponse] API response.
        def sleep_until(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'sleep_until',
            request_class: Temporalio::Api::TestService::V1::SleepUntilRequest,
            response_class: Temporalio::Api::TestService::V1::SleepResponse,
            request:,
            rpc_options:
          )
        end

        # Calls TestService.UnlockTimeSkippingWithSleep API call.
        #
        # @param request [Temporalio::Api::TestService::V1::SleepRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::TestService::V1::SleepResponse] API response.
        def unlock_time_skipping_with_sleep(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'unlock_time_skipping_with_sleep',
            request_class: Temporalio::Api::TestService::V1::SleepRequest,
            response_class: Temporalio::Api::TestService::V1::SleepResponse,
            request:,
            rpc_options:
          )
        end

        # Calls TestService.GetCurrentTime API call.
        #
        # @param request [Google::Protobuf::Empty] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::TestService::V1::GetCurrentTimeResponse] API response.
        def get_current_time(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'get_current_time',
            request_class: Google::Protobuf::Empty,
            response_class: Temporalio::Api::TestService::V1::GetCurrentTimeResponse,
            request:,
            rpc_options:
          )
        end
      end
    end
  end
end
