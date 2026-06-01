# typed: true

# Sorbet RBI types for the Temporal Ruby SDK.
# This file was split from rbi/temporalio.rbi by extra/split_rbi.rb.

class Temporalio::Worker::WorkflowExecutor
  extend T::Sig

  sig { void }
  def initialize; end
end
