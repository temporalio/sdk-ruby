# frozen_string_literal: true

require 'temporalio/api'

module Temporalio
  class Client
    # More detailed breakdown of a running activity's state.
    #
    # WARNING: Standalone Activities are experimental.
    module PendingActivityState
      SCHEDULED = Api::Enums::V1::PendingActivityState::PENDING_ACTIVITY_STATE_SCHEDULED
      STARTED = Api::Enums::V1::PendingActivityState::PENDING_ACTIVITY_STATE_STARTED
      CANCEL_REQUESTED = Api::Enums::V1::PendingActivityState::PENDING_ACTIVITY_STATE_CANCEL_REQUESTED
      PAUSED = Api::Enums::V1::PendingActivityState::PENDING_ACTIVITY_STATE_PAUSED
      PAUSE_REQUESTED = Api::Enums::V1::PendingActivityState::PENDING_ACTIVITY_STATE_PAUSE_REQUESTED
    end
  end
end
