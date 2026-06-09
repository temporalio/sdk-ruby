# frozen_string_literal: true

require 'temporalio/api'

module Temporalio
  class Client
    # Status of a standalone activity execution.
    #
    # WARNING: Standalone Activities are experimental.
    module ActivityExecutionStatus
      UNSPECIFIED = Api::Enums::V1::ActivityExecutionStatus::ACTIVITY_EXECUTION_STATUS_UNSPECIFIED
      RUNNING = Api::Enums::V1::ActivityExecutionStatus::ACTIVITY_EXECUTION_STATUS_RUNNING
      COMPLETED = Api::Enums::V1::ActivityExecutionStatus::ACTIVITY_EXECUTION_STATUS_COMPLETED
      FAILED = Api::Enums::V1::ActivityExecutionStatus::ACTIVITY_EXECUTION_STATUS_FAILED
      CANCELED = Api::Enums::V1::ActivityExecutionStatus::ACTIVITY_EXECUTION_STATUS_CANCELED
      TERMINATED = Api::Enums::V1::ActivityExecutionStatus::ACTIVITY_EXECUTION_STATUS_TERMINATED
      TIMED_OUT = Api::Enums::V1::ActivityExecutionStatus::ACTIVITY_EXECUTION_STATUS_TIMED_OUT
    end
  end
end
