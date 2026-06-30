# typed: true

module Temporalio::Client::PendingActivityState
  SCHEDULED = T.let(T.unsafe(nil), Integer)
  STARTED = T.let(T.unsafe(nil), Integer)
  CANCEL_REQUESTED = T.let(T.unsafe(nil), Integer)
  PAUSED = T.let(T.unsafe(nil), Integer)
  PAUSE_REQUESTED = T.let(T.unsafe(nil), Integer)
end
