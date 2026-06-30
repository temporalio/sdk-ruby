# typed: true

module Temporalio::Client::WorkflowExecutionStatus
  RUNNING = T.let(T.unsafe(nil), Integer)
  COMPLETED = T.let(T.unsafe(nil), Integer)
  FAILED = T.let(T.unsafe(nil), Integer)
  CANCELED = T.let(T.unsafe(nil), Integer)
  TERMINATED = T.let(T.unsafe(nil), Integer)
  CONTINUED_AS_NEW = T.let(T.unsafe(nil), Integer)
  TIMED_OUT = T.let(T.unsafe(nil), Integer)
end
