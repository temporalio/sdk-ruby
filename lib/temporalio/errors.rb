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

    # Superclass for internal errors
    class Internal < Error; end

    class WorkerShutdown < Internal; end

    # This error is used within the SDK to communicate Activity cancellations
    # (and whether it was requested by server or not)
    class ActivityCancelled < Internal
      def initialize(reason, by_request)
        super(reason)
        @by_request = by_request
      end

      def by_request?
        @by_request
      end
    end
  end
end
