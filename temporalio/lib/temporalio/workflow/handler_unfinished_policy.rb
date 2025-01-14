# frozen_string_literal: true

module Temporalio
  module Workflow
    # Actions taken if a workflow completes with running handlers.
    module HandlerUnfinishedPolicy
      # Issue a warning in addition to abandoning.
      WARN_AND_ABANDON = 1
      # Abandon the handler with no warning.
      ABANDON = 2
    end
  end
end
