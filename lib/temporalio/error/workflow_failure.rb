require 'temporalio/errors'

module Temporalio
  class Error
    # Used as a wrapper to perserve failure hierarchy in nested calls
    # i.e. WorkflowFailure(ActivityError(WorkflowFailure(CancelledError)))
    class WorkflowFailure < Error
      attr_reader :cause

      def initialize(cause:)
        super

        @cause = cause
      end
    end
  end
end
