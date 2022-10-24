require 'temporal/api/enums/v1/workflow_pb'

module Temporal
  module TimeoutType
    TYPES = [
      START_TO_CLOSE = :START_TO_CLOSE,
      SCHEDULE_TO_START = :SCHEDULE_TO_START,
      SCHEDULE_TO_CLOSE = :SCHEDULE_TO_CLOSE,
      HEARTBEAT = :HEARTBEAT,
    ].freeze

    API_MAP = {
      'TIMEOUT_TYPE_START_TO_CLOSE' => START_TO_CLOSE,
      'TIMEOUT_TYPE_SCHEDULE_TO_START' => SCHEDULE_TO_START,
      'TIMEOUT_TYPE_SCHEDULE_TO_CLOSE' => SCHEDULE_TO_CLOSE,
      'TIMEOUT_TYPE_HEARTBEAT' => HEARTBEAT,
    }.freeze

    def self.to_raw(type)
      Temporal::Api::Enums::V1::TimeoutType.resolve(API_MAP.invert[type].to_sym)
    end

    def self.from_raw(raw_type)
      API_MAP[raw_type.to_s]
    end
  end
end
