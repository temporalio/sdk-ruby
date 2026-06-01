# typed: true

# Sorbet RBI types for the Temporal Ruby SDK.
# This file was split from rbi/temporalio.rbi by extra/split_rbi.rb.

module Temporalio::Client::WorkflowUpdateWaitStage
  ADMITTED = T.let(T.unsafe(nil), Integer)
  ACCEPTED = T.let(T.unsafe(nil), Integer)
  COMPLETED = T.let(T.unsafe(nil), Integer)
end
