module Temporal
  # Superclass for all Temporal errors
  class Error < StandardError
    # Superclass for RPC and proto related errors
    class RPCError < Error; end

    class UnexpectedResponse < RPCError; end

    class UnsupportedQuery < RPCError; end

    class QueryRejected < RPCError
      attr_reader :status

      def initialize(status)
        super("Query rejected, workflow status: #{status}")
        @status = status
      end
    end
  end
end
