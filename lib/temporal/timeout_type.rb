module Temporal
  module TimeoutType
    TYPES = [
      START_TO_CLOSE = :START_TO_CLOSE,
      SCHEDULE_TO_START = :SCHEDULE_TO_START,
      SCHEDULE_TO_CLOSE = :SCHEDULE_TO_CLOSE,
      HEARTBEAT = :HEARTBEAT,
    ].freeze

    API_MAP = {
      TIMEOUT_TYPE_START_TO_CLOSE: START_TO_CLOSE,
      TIMEOUT_TYPE_SCHEDULE_TO_START: SCHEDULE_TO_START,
      TIMEOUT_TYPE_SCHEDULE_TO_CLOSE: SCHEDULE_TO_CLOSE,
      TIMEOUT_TYPE_HEARTBEAT: HEARTBEAT,
    }

    def self.to_raw(type)
      API_MAP.invert[type] || :TIMEOUT_TYPE_UNSPECIFIED
    end

    def self.from_raw(raw_type)
      API_MAP[raw_type]
    end
  end
end
