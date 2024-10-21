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

        def invoke_rpc(rpc:, request_class:, response_class:, request:, rpc_options:)
          raise 'Invalid request type' unless request.is_a?(request_class)

          begin
            @connection._core_client._invoke_rpc(
              service: @service,
              rpc:,
              request:,
              response_class:,
              rpc_options:
            )
          rescue Internal::Bridge::Client::RPCFailure => e
            if e.code == Error::RPCError::Code::CANCELED && e.message == '<__user_canceled__>'
              raise Error::CanceledError, 'User canceled'
            end

            raise Error::RPCError.new(e.message, code: e.code, raw_grpc_status: e.details)
          end
        end
      end
    end
  end
end
