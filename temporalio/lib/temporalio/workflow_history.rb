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

    # @return [String] ID of the workflow, extracted from the first event.
    def workflow_id
      start = events.first&.workflow_execution_started_event_attributes
      raise 'First event not a start event' if start.nil?

      start.workflow_id
    end
  end
end
