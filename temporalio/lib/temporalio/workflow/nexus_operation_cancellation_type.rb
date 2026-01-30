# frozen_string_literal: true

require 'temporalio/internal/bridge/api'

module Temporalio
  module Workflow
    # How a Nexus operation should handle cancellation.
    #
    # WARNING: Nexus support is experimental.
    module NexusOperationCancellationType
      # Wait for cancellation to complete (default).
      WAIT_CANCELLATION_COMPLETED = Internal::Bridge::Api::Nexus::NexusOperationCancellationType::WAIT_CANCELLATION_COMPLETED
      # Abandon the operation without sending a cancellation request.
      ABANDON = Internal::Bridge::Api::Nexus::NexusOperationCancellationType::ABANDON
      # Send a cancellation request but do not wait for confirmation.
      TRY_CANCEL = Internal::Bridge::Api::Nexus::NexusOperationCancellationType::TRY_CANCEL
      # Wait for the server to confirm the cancellation request was delivered.
      WAIT_CANCELLATION_REQUESTED = Internal::Bridge::Api::Nexus::NexusOperationCancellationType::WAIT_CANCELLATION_REQUESTED
    end
  end
end
