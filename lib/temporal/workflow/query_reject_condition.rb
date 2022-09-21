module Temporal
  class Workflow
    module QueryRejectCondition
      CONDITIONS = [
        NONE = :NONE,
        NOT_OPEN = :NOT_OPEN,
        NOT_COMPLETED_CLEANLY = :NOT_COMPLETED_CLEANLY,
      ].freeze

      API_CONDITIONS_MAP = {
        QUERY_REJECT_CONDITION_NONE: NONE,
        QUERY_REJECT_CONDITION_NOT_OPEN: NOT_OPEN,
        QUERY_REJECT_CONDITION_NOT_COMPLETED_CLEANLY: NOT_COMPLETED_CLEANLY,
      }.freeze

      def self.to_raw(condition)
        API_CONDITIONS_MAP.invert[condition]
      end

      def self.from_raw(raw_condition)
        API_CONDITIONS_MAP[raw_condition]
      end
    end
  end
end
