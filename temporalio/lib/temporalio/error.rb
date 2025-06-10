# frozen_string_literal: true

require 'temporalio/api'

module Temporalio
  # Superclass for all Temporal errors
  class Error < StandardError
    # Whether the error represents some form of cancellation from an activity or workflow.
    #
    # @param error [Exception] Error to check.
    # @return [Boolean] True if some form of canceled, false otherwise.
    def self.canceled?(error)
      error.is_a?(CanceledError) ||
        (error.is_a?(ActivityError) && error.cause.is_a?(CanceledError)) ||
        (error.is_a?(ChildWorkflowError) && error.cause.is_a?(CanceledError))
    end

    # @!visibility private
    def self._with_backtrace_and_cause(err, backtrace:, cause:)
      if cause
        # The only way to set a _real_ cause in Ruby is to use `raise`. Even if
        # you try to override `def cause`, it won't be outputted in situations
        # where Ruby outputs cause.
        begin
          raise(err, err.message, backtrace, cause:)
        rescue StandardError => e
          e
        end
      else
        err.set_backtrace(backtrace) if backtrace
        err
      end
    end

    # Error that is returned from  when a workflow is unsuccessful.
    class WorkflowFailedError < Error
      # @!visibility private
      def initialize(message = 'Workflow execution failed')
        super
      end
    end

    # Error that occurs when a workflow was continued as new.
    class WorkflowContinuedAsNewError < Error
      # @return [String] New execution run ID the workflow continued to.
      attr_reader :new_run_id

      # @!visibility private
      def initialize(new_run_id:)
        super('Workflow execution continued as new')
        @new_run_id = new_run_id
      end
    end

    # Error that occurs when a query fails.
    class WorkflowQueryFailedError < Error
    end

    # Error that occurs when a query was rejected.
    class WorkflowQueryRejectedError < Error
      # @return [Client::WorkflowExecutionStatus] Workflow execution status causing rejection.
      attr_reader :status

      # @!visibility private
      def initialize(status:)
        super("Query rejected, #{status}")
        @status = status
      end
    end

    # Error that occurs when an update fails.
    class WorkflowUpdateFailedError < Error
      # @!visibility private
      def initialize
        super('Workflow update failed')
      end
    end

    # Error that occurs when update RPC call times out or is canceled.
    #
    # @note This is not related to any general concept of timing out or cancelling a running update, this is only
    # related to the client call itself.
    class WorkflowUpdateRPCTimeoutOrCanceledError < Error
      # @!visibility private
      def initialize
        super('Timeout or cancellation waiting for update')
      end
    end

    # Error when a schedule is already running.
    class ScheduleAlreadyRunningError < Error
      # @!visibility private
      def initialize
        super('Schedule already running')
      end
    end

    # Error that occurs when an async activity handle tries to heartbeat and the activity is marked as canceled.
    class AsyncActivityCanceledError < Error
      # @!visibility private
      def initialize
        super('Activity canceled')
      end
    end

    # Error raised by a client for a general RPC failure.
    class RPCError < Error
      # @return [Code] Status code for the error.
      attr_reader :code

      # @!visibility private
      def initialize(message, code:, raw_grpc_status:)
        super(message)
        @code = code
        @raw_grpc_status = raw_grpc_status
      end

      # @return [Api::Common::V1::GrpcStatus] Status of the gRPC call with details.
      def grpc_status
        @grpc_status ||= create_grpc_status
      end

      private

      def create_grpc_status
        return Api::Common::V1::GrpcStatus.new(code: @code) unless @raw_grpc_status
        return @raw_grpc_status if @raw_grpc_status.is_a?(Api::Common::V1::GrpcStatus)

        Api::Common::V1::GrpcStatus.decode(@raw_grpc_status)
      end

      # Status code for RPC errors. These are gRPC status codes.
      module Code
        OK = 0
        CANCELED = 1 # Intentionally one-L while gRPC is two-L
        UNKNOWN = 2
        INVALID_ARGUMENT = 3
        DEADLINE_EXCEEDED = 4
        NOT_FOUND = 5
        ALREADY_EXISTS = 6
        PERMISSION_DENIED = 7
        RESOURCE_EXHAUSTED = 8
        FAILED_PRECONDITION = 9
        ABORTED = 10
        OUT_OF_RANGE = 11
        UNIMPLEMENTED = 12
        INTERNAL = 13
        UNAVAILABLE = 14
        DATA_LOSS = 15
        UNAUTHENTICATED = 16
      end
    end
  end
end

require 'temporalio/error/failure'
