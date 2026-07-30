# typed: true

module Temporalio::Workflow::ActivityCancellationType
  TRY_CANCEL = T.let(T.unsafe(nil), Integer)
  WAIT_CANCELLATION_COMPLETED = T.let(T.unsafe(nil), Integer)
  ABANDON = T.let(T.unsafe(nil), Integer)
end
