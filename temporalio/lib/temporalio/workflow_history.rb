# frozen_string_literal: true

module Temporalio
  # Representation of a workflow's history.
  class WorkflowHistory
    # History events for the workflow.
    attr_reader :events

    # @!visibility private
    def initialize(events)
      @events = events
    end
  end
end
