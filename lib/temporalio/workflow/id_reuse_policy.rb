require 'temporal/api/enums/v1/workflow_pb'

module Temporalio
  class Workflow
    # How already-in-use workflow IDs are handled on start.
    #
    # @see Temporalio::Api::Enums::V1::WorkflowIdReusePolicy
    class IDReusePolicy
      POLICIES = [
        ALLOW_DUPLICATE = :ALLOW_DUPLICATE,
        ALLOW_DUPLICATE_FAILED_ONLY = :ALLOW_DUPLICATE_FAILED_ONLY,
        REJECT_DUPLICATE = :REJECT_DUPLICATE,
        TERMINATE_IF_RUNNING = :TERMINATE_IF_RUNNING,
      ].freeze

      API_MAP = {
        Temporalio::Api::Enums::V1::WorkflowIdReusePolicy::WORKFLOW_ID_REUSE_POLICY_ALLOW_DUPLICATE =>
          ALLOW_DUPLICATE,
        Temporalio::Api::Enums::V1::WorkflowIdReusePolicy::WORKFLOW_ID_REUSE_POLICY_ALLOW_DUPLICATE_FAILED_ONLY =>
          ALLOW_DUPLICATE_FAILED_ONLY,
        Temporalio::Api::Enums::V1::WorkflowIdReusePolicy::WORKFLOW_ID_REUSE_POLICY_REJECT_DUPLICATE =>
          REJECT_DUPLICATE,
        Temporalio::Api::Enums::V1::WorkflowIdReusePolicy::WORKFLOW_ID_REUSE_POLICY_TERMINATE_IF_RUNNING =>
          TERMINATE_IF_RUNNING,
      }.freeze

      def self.to_raw(policy)
        API_MAP.invert[policy]
      end

      def self.from_raw(raw_policy)
        API_MAP[raw_policy]
      end
    end
  end
end
