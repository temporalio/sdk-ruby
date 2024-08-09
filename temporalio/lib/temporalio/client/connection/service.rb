# frozen_string_literal: true

require 'google/protobuf'
require 'temporalio/api'
require 'temporalio/error'

module Temporalio
  class Client
    class Connection
      # Base class for raw gRPC services.
      class Service
        # @!visibility private
        def initialize(connection, service)
          @connection = connection
          @service = service
        end

        protected

        def invoke_rpc(rpc:, request_class:, response_class:, request:, rpc_retry:, rpc_metadata:,
                       rpc_timeout:)
          raise 'Invalid request type' unless request.is_a?(request_class)

          begin
            @connection._core_client._invoke_rpc(
              service: @service,
              rpc:,
              request:,
              response_class:,
              rpc_retry:,
              rpc_metadata:,
              rpc_timeout:
            )
          rescue Internal::Bridge::Client::RpcFailure => e
            raise Error::RPCError.new(e.message, code: e.code, raw_grpc_status: e.details)
          end
        end
      end
    end
  end
end
