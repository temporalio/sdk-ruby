# frozen_string_literal: true

require 'google/protobuf'
require 'temporalio/api'

module Temporalio
  class Client
    class Connection
      # Base class for raw gRPC services.
      class Service
        # @!visibility private
        def self.rpc_methods(service, service_name)
          # Do service lookup
          desc = Google::Protobuf::DescriptorPool.generated_pool.lookup(service_name)
          raise 'Failed finding service descriptor' unless desc

          # Create an RPC call for each method
          desc.each do |method|
            # Camel case to snake case
            rpc = method.name.gsub(/([A-Z])/, '_\1').downcase.delete_prefix('_')
            define_method(rpc.to_sym) do |request, rpc_retry: false, rpc_metadata: {}, rpc_timeout_ms: 0|
              raise 'Invalid request type' unless request.is_a?(method.input_type.msgclass)

              @connection._core_client._invoke_rpc(
                service:,
                rpc:,
                request:,
                response_class: method.output_type.msgclass,
                rpc_retry:,
                rpc_metadata:,
                rpc_timeout_ms:
              )
            end
          end
        end

        private_class_method :rpc_methods

        # @!visibility private
        def initialize(connection)
          @connection = connection
        end
      end
    end
  end
end
