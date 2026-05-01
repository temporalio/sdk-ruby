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

  # Specifies the versioning behavior for the first task of a new run after continue-as-new. This is currently
  # experimental.
  module ContinueAsNewVersioningBehavior
    # Unspecified. Follow existing continue-as-new inheritance semantics.
    UNSPECIFIED =
      Api::Enums::V1::ContinueAsNewVersioningBehavior::CONTINUE_AS_NEW_VERSIONING_BEHAVIOR_UNSPECIFIED
    # Start the new run with AutoUpgrade behavior. Use the Target Version of the workflow's task queue at start-time.
    # After the first workflow task completes, use whatever Versioning Behavior the workflow is annotated with in the
    # workflow code.
    AUTO_UPGRADE =
      Api::Enums::V1::ContinueAsNewVersioningBehavior::CONTINUE_AS_NEW_VERSIONING_BEHAVIOR_AUTO_UPGRADE
    # Use the Ramping Version of the workflow's task queue at start time, regardless of the workflow's
    # Target Version (according to f(workflow_id, ramp_percentage)). After the first workflow task completes,
    # the workflow will use whatever Versioning Behavior it is annotated with. If there is no Ramping
    # Version by the time that the first workflow task is dispatched, it will be sent to the Current Version.
    #
    # It is highly discouraged to use this if the workflow is annotated with AutoUpgrade behavior, because
    # this setting ONLY applies to the first task of the workflow. If, after the first task, the workflow
    # is AutoUpgrade, it will behave like a normal AutoUpgrade workflow and go to the Target Version, which
    # may be the Current Version instead of the Ramping Version.
    #
    # Note that if the workflow being continued has a Pinned override, that override will be inherited by the
    # new workflow run regardless of the ContinueAsNewVersioningBehavior specified in the continue-as-new
    # command. Versioning Override always takes precedence until it's removed manually via UpdateWorkflowExecutionOptions.
    USE_RAMPING_VERSION =
      Api::Enums::V1::ContinueAsNewVersioningBehavior::CONTINUE_AS_NEW_VERSIONING_BEHAVIOR_USE_RAMPING_VERSION
  end

  # Specifies why the server suggests continue-as-new. This is currently experimental.
  module SuggestContinueAsNewReason
    # Unspecified.
    UNSPECIFIED =
      Api::Enums::V1::SuggestContinueAsNewReason::SUGGEST_CONTINUE_AS_NEW_REASON_UNSPECIFIED
    # Workflow History size is getting too large.
    HISTORY_SIZE_TOO_LARGE =
      Api::Enums::V1::SuggestContinueAsNewReason::SUGGEST_CONTINUE_AS_NEW_REASON_HISTORY_SIZE_TOO_LARGE
    # Workflow History event count is getting too large.
    TOO_MANY_HISTORY_EVENTS =
      Api::Enums::V1::SuggestContinueAsNewReason::SUGGEST_CONTINUE_AS_NEW_REASON_TOO_MANY_HISTORY_EVENTS
    # Workflow's count of completed plus in-flight updates is too large.
    TOO_MANY_UPDATES =
      Api::Enums::V1::SuggestContinueAsNewReason::SUGGEST_CONTINUE_AS_NEW_REASON_TOO_MANY_UPDATES
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
