# frozen_string_literal: true

require 'temporalio/api'

module Temporalio
  class Client
    # Status of a workflow execution.
    module WorkflowExecutionStatus
      RUNNING = Api::Enums::V1::WorkflowExecutionStatus::WORKFLOW_EXECUTION_STATUS_RUNNING
      COMPLETED = Api::Enums::V1::WorkflowExecutionStatus::WORKFLOW_EXECUTION_STATUS_COMPLETED
      FAILED = Api::Enums::V1::WorkflowExecutionStatus::WORKFLOW_EXECUTION_STATUS_FAILED
      CANCELED = Api::Enums::V1::WorkflowExecutionStatus::WORKFLOW_EXECUTION_STATUS_CANCELED
      TERMINATED = Api::Enums::V1::WorkflowExecutionStatus::WORKFLOW_EXECUTION_STATUS_TERMINATED
      CONTINUED_AS_NEW = Api::Enums::V1::WorkflowExecutionStatus::WORKFLOW_EXECUTION_STATUS_CONTINUED_AS_NEW
      TIMED_OUT = Api::Enums::V1::WorkflowExecutionStatus::WORKFLOW_EXECUTION_STATUS_TIMED_OUT
    end
  end
end
