# frozen_string_literal: true

require 'delegate'

module Temporalio
  module Internal
    module Worker
      class WorkflowInstance
        # Delegator to a hash that does not allow external mutations. Used for memo.
        class ExternallyImmutableHash < SimpleDelegator
          def initialize(initial_hash)
            super(initial_hash.freeze)
          end

          def _update(&)
            new_hash = __getobj__.dup
            yield new_hash
            __setobj__(new_hash.freeze)
          end
        end
      end
    end
  end
end
