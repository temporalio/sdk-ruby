# frozen_string_literal: true

require 'temporalio/api'

module Temporalio
  # How already-in-use workflow IDs are handled on start.
  #
  # @see https://docs.temporal.io/workflows#workflow-id-reuse-policy
  module WorkflowIDReusePolicy
    # Allow starting a workflow execution using the same workflow ID.
    ALLOW_DUPLICATE = Api::Enums::V1::WorkflowIdReusePolicy::WORKFLOW_ID_REUSE_POLICY_ALLOW_DUPLICATE
    # Allow starting a workflow execution using the same workflow ID, only when the last execution's final state is one
    # of terminated, canceled, timed out, or failed.
    ALLOW_DUPLICATE_FAILED_ONLY =
      Api::Enums::V1::WorkflowIdReusePolicy::WORKFLOW_ID_REUSE_POLICY_ALLOW_DUPLICATE_FAILED_ONLY
    # Do not permit re-use of the workflow ID for this workflow. Future start workflow requests could potentially change
    # the policy, allowing re-use of the workflow ID.
    REJECT_DUPLICATE = Api::Enums::V1::WorkflowIdReusePolicy::WORKFLOW_ID_REUSE_POLICY_REJECT_DUPLICATE
    # This option is {WorkflowIDConflictPolicy::TERMINATE_EXISTING} but is here for backwards compatibility. If
    # specified, it acts like {ALLOW_DUPLICATE}, but also the {WorkflowIDConflictPolicy} on the request is treated as
    # {WorkflowIDConflictPolicy::TERMINATE_EXISTING}. If no running workflow, then the behavior is the same as
    # {ALLOW_DUPLICATE}.
    #
    # @deprecated Use {WorkflowIDConflictPolicy::TERMINATE_EXISTING} instead.
    TERMINATE_IF_RUNNING = Api::Enums::V1::WorkflowIdReusePolicy::WORKFLOW_ID_REUSE_POLICY_TERMINATE_IF_RUNNING
  end

  # How already-running workflows of the same ID are handled on start.
  #
  # @see https://docs.temporal.io/workflows#workflow-id-conflict-policy
  module WorkflowIDConflictPolicy
    # Unset.
    UNSPECIFIED = Api::Enums::V1::WorkflowIdConflictPolicy::WORKFLOW_ID_CONFLICT_POLICY_UNSPECIFIED
    # Don't start a new workflow, instead fail with already-started error.
    FAIL = Api::Enums::V1::WorkflowIdConflictPolicy::WORKFLOW_ID_CONFLICT_POLICY_FAIL
    # Don't start a new workflow, instead return a workflow handle for the running workflow.
    USE_EXISTING = Api::Enums::V1::WorkflowIdConflictPolicy::WORKFLOW_ID_CONFLICT_POLICY_USE_EXISTING
    # Terminate the running workflow before starting a new one.
    TERMINATE_EXISTING = Api::Enums::V1::WorkflowIdConflictPolicy::WORKFLOW_ID_CONFLICT_POLICY_TERMINATE_EXISTING
  end

  # Specifies when a workflow might move from a worker of one Build Id to another.
  module VersioningBehavior
    # Unspecified versioning behavior. By default, workers opting into worker versioning will
    # be required to specify a behavior.
    UNSPECIFIED = Api::Enums::V1::VersioningBehavior::VERSIONING_BEHAVIOR_UNSPECIFIED
    # The workflow will be pinned to the current Build ID unless manually moved.
    PINNED = Api::Enums::V1::VersioningBehavior::VERSIONING_BEHAVIOR_PINNED
    # The workflow will automatically move to the latest version (default Build ID of the task
    # queue) when the next task is dispatched.
    AUTO_UPGRADE = Api::Enums::V1::VersioningBehavior::VERSIONING_BEHAVIOR_AUTO_UPGRADE
  end
end
