# frozen_string_literal: true

require 'temporalio/api'

module Temporalio
  # Superclass for all Temporal errors
  class Error < StandardError
    # Error that is returned from  when a workflow is unsuccessful.
    class WorkflowFailureError < Error
      # @return [Exception] Cause of the failure.
      attr_reader :cause

      # @param cause [Exception] Cause of the failure.
      def initialize(cause:)
        super('Workflow failed')

        @cause = cause
      end
    end

    # Error that occurs when a workflow was continued as new.
    class WorkflowContinuedAsNewError < Error
      # @return [String] New execution run ID the workflow continued to.
      attr_reader :new_run_id

      # @param new_run_id [String] New execution run ID the workflow continued to.
      def initialize(new_run_id:)
        super('Workflow execution continued as new')
        @new_run_id = new_run_id
      end
    end

    # Error raised by a client or workflow when a workflow execution has already started.
    class WorkflowAlreadyStartedError < Error
      # @return [String] ID of the already-started workflow.
      attr_reader :workflow_id

      # @return [String] Workflow type name of the already-started workflow.
      attr_reader :workflow_type

      # @return [String] Run ID of the already-started workflow if this was raised by the client.
      attr_reader :run_id

      def initialize(workflow_id:, workflow_type:, run_id:)
        super('Workflow execution already started')
        @workflow_id = workflow_id
        @workflow_type = workflow_type
        @run_id = run_id
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

        Api::Common::V1::GrpcStatus.decode(@raw_grpc_status)
      end

      # Status code for RPC errors. These are gRPC status codes.
      module Code
        OK = 0
        CANCELLED = 1
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
