# frozen_string_literal: true

require 'temporalio/internal/bridge/api'

module Temporalio
  module Workflow
    # Cancellation types for activities.
    module ActivityCancellationType
      # Initiate a cancellation request and immediately report cancellation to the workflow.
      TRY_CANCEL = Internal::Bridge::Api::WorkflowCommands::ActivityCancellationType::TRY_CANCEL
      # Wait for activity cancellation completion. Note that activity must heartbeat to receive a cancellation
      # notification. This can block the cancellation for a long time if activity doesn't heartbeat or chooses to ignore
      # the cancellation request.
      WAIT_CANCELLATION_COMPLETED =
        Internal::Bridge::Api::WorkflowCommands::ActivityCancellationType::WAIT_CANCELLATION_COMPLETED
      # Do not request cancellation of the activity and immediately report cancellation to the workflow.
      ABANDON = Internal::Bridge::Api::WorkflowCommands::ActivityCancellationType::ABANDON
    end
  end
end
