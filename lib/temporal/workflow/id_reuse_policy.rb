module Temporal
  class Workflow
    class IDReusePolicy
      POLICIES = [
        ALLOW_DUPLICATE = :ALLOW_DUPLICATE,
        ALLOW_DUPLICATE_FAILED_ONLY = :ALLOW_DUPLICATE_FAILED_ONLY,
        REJECT_DUPLICATE = :REJECT_DUPLICATE,
      ].freeze

      API_POLICY_MAP = {
        WORKFLOW_ID_REUSE_POLICY_ALLOW_DUPLICATE: ALLOW_DUPLICATE,
        WORKFLOW_ID_REUSE_POLICY_ALLOW_DUPLICATE_FAILED_ONLY: ALLOW_DUPLICATE_FAILED_ONLY,
        WORKFLOW_ID_REUSE_POLICY_REJECT_DUPLICATE: REJECT_DUPLICATE,
      }.freeze

      def self.to_raw(policy)
        API_POLICY_MAP.invert[policy]
      end

      def self.from_raw(raw_policy)
        API_POLICY_MAP[raw_policy]
      end
    end
  end
end
