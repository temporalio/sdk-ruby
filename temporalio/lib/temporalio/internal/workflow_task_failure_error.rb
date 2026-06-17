# frozen_string_literal: true

module Temporalio
  module Internal
    # Marker for internal exceptions that must escape workflow fibers and fail the workflow task.
    module WorkflowTaskFailureError
    end
  end
end
