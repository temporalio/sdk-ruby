module Temporalio
  # Current retry state of the workflow/activity during error.
  module RetryState
    STATES = [
      IN_PROGRESS = :IN_PROGRESS,
      NON_RETRYABLE_FAILURE = :NON_RETRYABLE_FAILURE,
      TIMEOUT = :TIMEOUT,
      MAXIMUM_ATTEMPTS_REACHED = :MAXIMUM_ATTEMPTS_REACHED,
      RETRY_POLICY_NOT_SET = :RETRY_POLICY_NOT_SET,
      INTERNAL_SERVER_ERROR = :INTERNAL_SERVER_ERROR,
      CANCEL_REQUESTED = :CANCEL_REQUESTED,
    ].freeze

    # RBS screws up style definitions when using .freeze
    # rubocop:disable Style/MutableConstant
    API_MAP = {
      RETRY_STATE_IN_PROGRESS: IN_PROGRESS,
      RETRY_STATE_NON_RETRYABLE_FAILURE: NON_RETRYABLE_FAILURE,
      RETRY_STATE_TIMEOUT: TIMEOUT,
      RETRY_STATE_MAXIMUM_ATTEMPTS_REACHED: MAXIMUM_ATTEMPTS_REACHED,
      RETRY_STATE_RETRY_POLICY_NOT_SET: RETRY_POLICY_NOT_SET,
      RETRY_STATE_INTERNAL_SERVER_ERROR: INTERNAL_SERVER_ERROR,
      RETRY_STATE_CANCEL_REQUESTED: CANCEL_REQUESTED,
    }
    # rubocop:enable Style/MutableConstant

    def self.to_raw(state)
      API_MAP.invert[state] || :RETRY_STATE_UNSPECIFIED
    end

    def self.from_raw(raw_state)
      API_MAP[raw_state]
    end
  end
end
