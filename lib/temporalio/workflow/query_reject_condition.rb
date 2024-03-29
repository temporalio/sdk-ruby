require 'temporal/api/enums/v1/query_pb'

module Temporalio
  class Workflow
    # Whether a query should be rejected in certain conditions.
    #
    # @see Temporalio::Api::Enums::V1::QueryRejectCondition
    module QueryRejectCondition
      CONDITIONS = [
        NONE = :NONE,
        NOT_OPEN = :NOT_OPEN,
        NOT_COMPLETED_CLEANLY = :NOT_COMPLETED_CLEANLY,
      ].freeze

      API_MAP = {
        Temporalio::Api::Enums::V1::QueryRejectCondition::QUERY_REJECT_CONDITION_NONE =>
          NONE,
        Temporalio::Api::Enums::V1::QueryRejectCondition::QUERY_REJECT_CONDITION_NOT_OPEN =>
          NOT_OPEN,
        Temporalio::Api::Enums::V1::QueryRejectCondition::QUERY_REJECT_CONDITION_NOT_COMPLETED_CLEANLY =>
          NOT_COMPLETED_CLEANLY,
      }.freeze

      def self.to_raw(condition)
        API_MAP.invert[condition]
      end

      def self.from_raw(raw_condition)
        API_MAP[raw_condition]
      end
    end
  end
end
