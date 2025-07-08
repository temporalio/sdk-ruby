# frozen_string_literal: true

require 'temporalio/workflow'

module Temporalio
  module Workflow
    # Handle for interacting with an external workflow.
    #
    # This is created via {Workflow.external_workflow_handle}, it is never instantiated directly.
    class ExternalWorkflowHandle
      # @!visibility private
      def initialize
        raise NotImplementedError, 'Cannot instantiate an external handle directly'
      end

      # @return [String] ID for the workflow.
      def id
        raise NotImplementedError
      end

      # @return [String, nil] Run ID for the workflow.
      def run_id
        raise NotImplementedError
      end

      # Signal the external workflow.
      #
      # @param signal [Workflow::Definition::Signal, Symbol, String] Signal definition or name.
      # @param args [Array<Object>] Signal args.
      # @param cancellation [Cancellation] Cancellation for canceling the signalling.
      # @param arg_hints [Array<Object>, nil] Overrides converter hints for arguments if any. If unset/nil and the
      #   signal definition has arg hints, those are used by default.
      def signal(signal, *args, cancellation: Workflow.cancellation, arg_hints: nil)
        raise NotImplementedError
      end

      # Cancel the external workflow.
      def cancel
        raise NotImplementedError
      end
    end
  end
end
