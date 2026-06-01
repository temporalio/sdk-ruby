# typed: true

# Sorbet RBI types for the Temporal Ruby SDK.
# This file was split from rbi/temporalio.rbi by extra/split_rbi.rb.

module Temporalio::Workflow::ParentClosePolicy
  UNSPECIFIED = T.let(T.unsafe(nil), Integer)
  TERMINATE = T.let(T.unsafe(nil), Integer)
  ABANDON = T.let(T.unsafe(nil), Integer)
  REQUEST_CANCEL = T.let(T.unsafe(nil), Integer)
end
