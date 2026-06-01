# typed: true

# Sorbet RBI types for the Temporal Ruby SDK.
# This file was split from rbi/temporalio.rbi by extra/split_rbi.rb.

module Temporalio::Client::WorkflowQueryRejectCondition
  NONE = T.let(T.unsafe(nil), Integer)
  NOT_OPEN = T.let(T.unsafe(nil), Integer)
  NOT_COMPLETED_CLEANLY = T.let(T.unsafe(nil), Integer)
end
