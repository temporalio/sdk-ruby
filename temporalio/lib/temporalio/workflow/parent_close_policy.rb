# frozen_string_literal: true

require 'temporalio/internal/bridge/api'

module Temporalio
  module Workflow
    # How a child workflow should be handled when the parent closes.
    module ParentClosePolicy
      # Unset.
      UNSPECIFIED = Internal::Bridge::Api::ChildWorkflow::ParentClosePolicy::PARENT_CLOSE_POLICY_UNSPECIFIED
      # The child workflow will also terminate.
      TERMINATE = Internal::Bridge::Api::ChildWorkflow::ParentClosePolicy::PARENT_CLOSE_POLICY_TERMINATE
      # The child workflow will do nothing.
      ABANDON = Internal::Bridge::Api::ChildWorkflow::ParentClosePolicy::PARENT_CLOSE_POLICY_ABANDON
      # Cancellation will be requested of the child workflow.
      REQUEST_CANCEL = Internal::Bridge::Api::ChildWorkflow::ParentClosePolicy::PARENT_CLOSE_POLICY_REQUEST_CANCEL
    end
  end
end
