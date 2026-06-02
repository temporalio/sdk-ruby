# typed: true

# Sorbet RBI types for the Temporal Ruby SDK.
# This file was split from rbi/temporalio.rbi by extra/split_rbi.rb.

class Temporalio::WorkflowHistory
  sig { params(events: T::Array[Temporalio::Api::History::V1::HistoryEvent]).void }
  def initialize(events); end

  sig { params(json: String).returns(Temporalio::WorkflowHistory) }
  def self.from_history_json(json); end

  sig { returns(T::Array[Temporalio::Api::History::V1::HistoryEvent]) }
  attr_reader :events

  sig { returns(String) }
  def workflow_id; end

  sig { returns(String) }
  def to_history_json; end

  sig { params(other: Temporalio::WorkflowHistory).returns(T::Boolean) }
  def ==(other); end
end
