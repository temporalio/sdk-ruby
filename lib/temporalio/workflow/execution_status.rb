module Temporalio
  class Workflow
    module ExecutionStatus
      STATUSES = [
        RUNNING = :RUNNING,
        COMPLETED = :COMPLETED,
        FAILED = :FAILED,
        CANCELED = :CANCELED,
        TERMINATED = :TERMINATED,
        CONTINUED_AS_NEW = :CONTINUED_AS_NEW,
        TIMED_OUT = :TIMED_OUT,
      ].freeze

      # RBS screws up style definitions when using .freeze
      # rubocop:disable Style/MutableConstant
      API_MAP = {
        WORKFLOW_EXECUTION_STATUS_RUNNING: RUNNING,
        WORKFLOW_EXECUTION_STATUS_COMPLETED: COMPLETED,
        WORKFLOW_EXECUTION_STATUS_FAILED: FAILED,
        WORKFLOW_EXECUTION_STATUS_CANCELED: CANCELED,
        WORKFLOW_EXECUTION_STATUS_TERMINATED: TERMINATED,
        WORKFLOW_EXECUTION_STATUS_CONTINUED_AS_NEW: CONTINUED_AS_NEW,
        WORKFLOW_EXECUTION_STATUS_TIMED_OUT: TIMED_OUT,
      }
      # rubocop:enable Style/MutableConstant

      def self.to_raw(status)
        API_MAP.invert[status]
      end

      def self.from_raw(raw_status)
        API_MAP[raw_status]
      end
    end
  end
end
