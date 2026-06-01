# typed: true

# Sorbet RBI types for the Temporal Ruby SDK.
# This file was split from rbi/temporalio.rbi by extra/split_rbi.rb.

module Temporalio::WorkflowIDReusePolicy
  ALLOW_DUPLICATE = T.let(T.unsafe(nil), Integer)

  ALLOW_DUPLICATE_FAILED_ONLY = T.let(T.unsafe(nil), Integer)

  REJECT_DUPLICATE = T.let(T.unsafe(nil), Integer)

  TERMINATE_IF_RUNNING = T.let(T.unsafe(nil), Integer)
end

module Temporalio::WorkflowIDConflictPolicy
  UNSPECIFIED = T.let(T.unsafe(nil), Integer)

  FAIL = T.let(T.unsafe(nil), Integer)

  USE_EXISTING = T.let(T.unsafe(nil), Integer)

  TERMINATE_EXISTING = T.let(T.unsafe(nil), Integer)
end

module Temporalio::ContinueAsNewVersioningBehavior
  UNSPECIFIED = T.let(T.unsafe(nil), Integer)

  AUTO_UPGRADE = T.let(T.unsafe(nil), Integer)
end

module Temporalio::SuggestContinueAsNewReason
  UNSPECIFIED = T.let(T.unsafe(nil), Integer)

  HISTORY_SIZE_TOO_LARGE = T.let(T.unsafe(nil), Integer)

  TOO_MANY_HISTORY_EVENTS = T.let(T.unsafe(nil), Integer)

  TOO_MANY_UPDATES = T.let(T.unsafe(nil), Integer)
end

module Temporalio::VersioningBehavior
  UNSPECIFIED = T.let(T.unsafe(nil), Integer)

  PINNED = T.let(T.unsafe(nil), Integer)

  AUTO_UPGRADE = T.let(T.unsafe(nil), Integer)
end
