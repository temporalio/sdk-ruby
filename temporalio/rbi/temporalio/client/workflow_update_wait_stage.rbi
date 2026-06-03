# typed: true

module Temporalio::Client::WorkflowUpdateWaitStage
  ADMITTED = T.let(T.unsafe(nil), Integer)
  ACCEPTED = T.let(T.unsafe(nil), Integer)
  COMPLETED = T.let(T.unsafe(nil), Integer)
end
