# frozen_string_literal: true

require 'temporalio/internal/bridge/api'

module Temporalio
  module Workflow
    # Cancellation types for child workflows.
    module ChildWorkflowCancellationType
      # Do not request cancellation of the child workflow if already scheduled.
      ABANDON = Internal::Bridge::Api::ChildWorkflow::ChildWorkflowCancellationType::ABANDON
      # Initiate a cancellation request and immediately report cancellation to the parent.
      TRY_CANCEL = Internal::Bridge::Api::ChildWorkflow::ChildWorkflowCancellationType::TRY_CANCEL
      # Wait for child cancellation completion.
      WAIT_CANCELLATION_COMPLETED =
        Internal::Bridge::Api::ChildWorkflow::ChildWorkflowCancellationType::WAIT_CANCELLATION_COMPLETED
      # Request cancellation of the child and wait for confirmation that the request was received.
      WAIT_CANCELLATION_REQUESTED =
        Internal::Bridge::Api::ChildWorkflow::ChildWorkflowCancellationType::WAIT_CANCELLATION_REQUESTED
    end
  end
end
