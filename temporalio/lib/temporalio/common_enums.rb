# frozen_string_literal: true

require 'temporalio/api'

module Temporalio
  # How already-in-use workflow IDs are handled on start.
  #
  # @see https://docs.temporal.io/workflows#workflow-id-reuse-policy
  module WorkflowIDReusePolicy
    ALLOW_DUPLICATE = Api::Enums::V1::WorkflowIdReusePolicy::WORKFLOW_ID_REUSE_POLICY_ALLOW_DUPLICATE
    ALLOW_DUPLICATE_FAILED_ONLY =
      Api::Enums::V1::WorkflowIdReusePolicy::WORKFLOW_ID_REUSE_POLICY_ALLOW_DUPLICATE_FAILED_ONLY
    REJECT_DUPLICATE = Api::Enums::V1::WorkflowIdReusePolicy::WORKFLOW_ID_REUSE_POLICY_REJECT_DUPLICATE
    TERMINATE_IF_RUNNING = Api::Enums::V1::WorkflowIdReusePolicy::WORKFLOW_ID_REUSE_POLICY_TERMINATE_IF_RUNNING
  end

  # How already-running workflows of the same ID are handled on start.
  module WorkflowIDConflictPolicy
    UNSPECIFIED = Api::Enums::V1::WorkflowIdConflictPolicy::WORKFLOW_ID_CONFLICT_POLICY_UNSPECIFIED
    FAIL = Api::Enums::V1::WorkflowIdConflictPolicy::WORKFLOW_ID_CONFLICT_POLICY_FAIL
    USE_EXISTING = Api::Enums::V1::WorkflowIdConflictPolicy::WORKFLOW_ID_CONFLICT_POLICY_USE_EXISTING
    TERMINATE_EXISTING = Api::Enums::V1::WorkflowIdConflictPolicy::WORKFLOW_ID_CONFLICT_POLICY_TERMINATE_EXISTING
  end
end
