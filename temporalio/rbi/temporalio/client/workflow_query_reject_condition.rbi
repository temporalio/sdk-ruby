# typed: true

module Temporalio::Client::WorkflowQueryRejectCondition
  NONE = T.let(T.unsafe(nil), Integer)
  NOT_OPEN = T.let(T.unsafe(nil), Integer)
  NOT_COMPLETED_CLEANLY = T.let(T.unsafe(nil), Integer)
end
