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

      # @return [Object, nil] Hint for the result if any.
      def result_hint
        raise NotImplementedError
      end

      # Wait for the result.
      #
      # @param result_hint [Object, nil] Override the result hint, or if nil uses the one on the handle.
      # @return [Object] Result of the child workflow.
      #
      # @raise [Error::ChildWorkflowError] Workflow failed with +cause+ as the cause.
      def result(result_hint: nil)
        raise NotImplementedError
      end

      # Signal the child workflow.
      #
      # @param signal [Workflow::Definition::Signal, Symbol, String] Signal definition or name.
      # @param args [Array<Object>] Signal args.
      # @param cancellation [Cancellation] Cancellation for canceling the signalling.
      # @param arg_hints [Array<Object>, nil] Overrides converter hints for arguments if any. If unset/nil and the
      #   signal definition has arg hints, those are used by default.
      def signal(signal, *args, cancellation: Workflow.cancellation, arg_hints: nil)
        raise NotImplementedError
      end
    end
  end
end
