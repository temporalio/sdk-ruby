# frozen_string_literal: true

module Temporalio
  module Workflow
    # Handle for interacting with a child workflow.
    #
    # This is created via {Workflow.start_child_workflow}, it is never instantiated directly.
    class ChildWorkflowHandle
      # @!visibility private
      def initialize
        raise NotImplementedError, 'Cannot instantiate a child handle directly'
      end

      # @return [String] ID for the workflow.
      def id
        raise NotImplementedError
      end

      # @return [String] Run ID for the workflow.
      def first_execution_run_id
        raise NotImplementedError
      end

      # Wait for the result.
      #
      # @return [Object] Result of the child workflow.
      #
      # @raise [Error::ChildWorkflowError] Workflow failed with +cause+ as the cause.
      def result
        raise NotImplementedError
      end

      # Signal the child workflow.
      #
      # @param signal [Workflow::Definition::Signal, Symbol, String] Signal definition or name.
      # @param args [Array<Object>] Signal args.
      # @param cancellation [Cancellation] Cancellation for canceling the signalling.
      def signal(signal, *args, cancellation: Workflow.cancellation)
        raise NotImplementedError
      end
    end
  end
end
