require 'temporal/api/enums/v1/workflow_pb'

module Temporal
  module RetryState
    TYPES = [
      IN_PROGRESS = :IN_PROGRESS,
      NON_RETRYABLE_FAILURE = :NON_RETRYABLE_FAILURE,
      TIMEOUT = :TIMEOUT,
      MAXIMUM_ATTEMPTS_REACHED = :MAXIMUM_ATTEMPTS_REACHED,
      RETRY_POLICY_NOT_SET = :RETRY_POLICY_NOT_SET,
      INTERNAL_SERVER_ERROR = :INTERNAL_SERVER_ERROR,
      CANCEL_REQUESTED = :CANCEL_REQUESTED,
    ].freeze

    API_MAP = {
      'RETRY_STATE_IN_PROGRESS' => IN_PROGRESS,
      'RETRY_STATE_NON_RETRYABLE_FAILURE' => NON_RETRYABLE_FAILURE,
      'RETRY_STATE_TIMEOUT' => TIMEOUT,
      'RETRY_STATE_MAXIMUM_ATTEMPTS_REACHED' => MAXIMUM_ATTEMPTS_REACHED,
      'RETRY_STATE_RETRY_POLICY_NOT_SET' => RETRY_POLICY_NOT_SET,
      'RETRY_STATE_INTERNAL_SERVER_ERROR' => INTERNAL_SERVER_ERROR,
      'RETRY_STATE_CANCEL_REQUESTED' => CANCEL_REQUESTED,
    }.freeze

    def self.to_raw(state)
      Temporal::Api::Enums::V1::RetryState.resolve(API_MAP.invert[state].to_sym)
    end

    def self.from_raw(raw_state)
      API_MAP[raw_state.to_s]
    end
  end
end
