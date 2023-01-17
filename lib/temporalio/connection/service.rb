module Temporalio
  class Connection
    # @abstract A superclass for defining services to interact with the Temporal API
    class Service
      # @api private
      def initialize(core_connection, service)
        @core_connection = core_connection
        @service = service
      end

      private

      attr_reader :core_connection, :service

      def call(rpc, bytes, metadata, timeout)
        core_connection.call(rpc, service, bytes, metadata, timeout)
      end
    end
  end
end
