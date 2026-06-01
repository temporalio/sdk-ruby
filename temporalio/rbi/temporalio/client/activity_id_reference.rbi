# typed: true

# Sorbet RBI types for the Temporal Ruby SDK.
# This file was split from rbi/temporalio.rbi by extra/split_rbi.rb.

class Temporalio::Client::ActivityIDReference
  sig { params(workflow_id: String, run_id: T.nilable(String), activity_id: String).void }
  def initialize(workflow_id:, run_id:, activity_id:); end

  sig { returns(String) }
  def workflow_id; end

  sig { returns(T.nilable(String)) }
  def run_id; end

  sig { returns(String) }
  def activity_id; end
end
