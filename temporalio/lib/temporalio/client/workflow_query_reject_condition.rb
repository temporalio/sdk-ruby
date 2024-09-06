# frozen_string_literal: true

require 'temporalio/api'

module Temporalio
  class Client
    # Whether a query should be rejected in certain conditions.
    module WorkflowQueryRejectCondition
      NONE = Api::Enums::V1::QueryRejectCondition::QUERY_REJECT_CONDITION_NONE
      NOT_OPEN = Api::Enums::V1::QueryRejectCondition::QUERY_REJECT_CONDITION_NOT_OPEN
      NOT_COMPLETED_CLEANLY = Api::Enums::V1::QueryRejectCondition::QUERY_REJECT_CONDITION_NOT_COMPLETED_CLEANLY
    end
  end
end
