# frozen_string_literal: true

require 'temporalio/api'

module Temporalio
  class Client
    # Stage to wait for workflow update to reach before returning from {WorkflowHandle.start_update}.
    module WorkflowUpdateWaitStage
      ADMITTED =
        Api::Enums::V1::UpdateWorkflowExecutionLifecycleStage::UPDATE_WORKFLOW_EXECUTION_LIFECYCLE_STAGE_ADMITTED
      ACCEPTED =
        Api::Enums::V1::UpdateWorkflowExecutionLifecycleStage::UPDATE_WORKFLOW_EXECUTION_LIFECYCLE_STAGE_ACCEPTED
      COMPLETED =
        Api::Enums::V1::UpdateWorkflowExecutionLifecycleStage::UPDATE_WORKFLOW_EXECUTION_LIFECYCLE_STAGE_COMPLETED
    end
  end
end
