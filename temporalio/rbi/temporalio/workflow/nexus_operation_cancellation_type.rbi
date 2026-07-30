# typed: true

module Temporalio::Workflow::NexusOperationCancellationType
  WAIT_CANCELLATION_COMPLETED = T.let(T.unsafe(nil), Integer)
  ABANDON = T.let(T.unsafe(nil), Integer)
  TRY_CANCEL = T.let(T.unsafe(nil), Integer)
  WAIT_CANCELLATION_REQUESTED = T.let(T.unsafe(nil), Integer)
end
