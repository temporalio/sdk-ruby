# typed: true

# Sorbet RBI types for the Temporal Ruby SDK.
# This file was split from rbi/temporalio.rbi by extra/split_rbi.rb.

module Temporalio::Workflow::ActivityCancellationType
  TRY_CANCEL = T.let(T.unsafe(nil), Integer)
  WAIT_CANCELLATION_COMPLETED = T.let(T.unsafe(nil), Integer)
  ABANDON = T.let(T.unsafe(nil), Integer)
end
