module Temporalio
  # Superclass for all Temporal errors
  class Error < StandardError
    # Superclass for RPC and proto related errors
    class RPCError < Error; end

    class UnexpectedResponse < RPCError; end

    class WorkflowExecutionAlreadyStarted < RPCError; end

    class QueryFailed < RPCError; end

    class QueryRejected < RPCError
      attr_reader :status

      def initialize(status)
        super("Query rejected, workflow status: #{status}")
        @status = status
      end
    end
  end
end
