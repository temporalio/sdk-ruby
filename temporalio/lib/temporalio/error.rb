# frozen_string_literal: true

module Temporalio
  # Superclass for all Temporal errors
  class Error < StandardError
    # Error that is returned from  when a workflow is unsuccessful.
    class WorkflowFailureError < Error
      # @return [Exception] Cause of the failure.
      attr_reader :cause

      # @param cause [Exception] Cause of the failure.
      def initialize(cause:)
        super

        @cause = cause
      end
    end

    # Error that occurs when a workflow was continued as new.
    class WorkflowContinuedAsNewError < Error
      # @return [String] New execution run ID the workflow continued to.
      attr_reader :new_run_id

      # @param [String] New execution run ID the workflow continued to.
      def initialize(new_run_id:)
        super('Workflow execution continued as new')
        @new_run_id = new_run_id
      end
    end

    class RPCError < Error
      # TODO
    end
  end
end

require 'temporalio/error/failure'
