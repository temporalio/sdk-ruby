# frozen_string_literal: true

require 'temporalio/api'

module Temporalio
  # Representation of a workflow's history.
  class WorkflowHistory
    # Convert a JSON string to workflow history. This supports the JSON format exported by Temporal UI and CLI.
    #
    # @param json [String] JSON string.
    # @return [WorkflowHistory] Converted history.
    def self.from_history_json(json)
      WorkflowHistory.new(Api::History::V1::History.decode_json(json).events.to_a)
    end

    # @return [Array<Api::History::V1::HistoryEvent>] History events for the workflow.
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

    # Convert to history JSON.
    #
    # @return [String] JSON string.
    def to_history_json
      Api::History::V1::History.encode_json(Api::History::V1::History.new(events:))
    end

    # Compare history.
    #
    # @param other [WorkflowHistory] Other history.
    # @return [Boolean] True if equal.
    def ==(other)
      other.is_a?(WorkflowHistory) && events == other.events
    end
  end
end
