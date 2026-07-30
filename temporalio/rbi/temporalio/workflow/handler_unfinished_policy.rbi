# typed: true

module Temporalio::Workflow::HandlerUnfinishedPolicy
  WARN_AND_ABANDON = T.let(T.unsafe(nil), Integer)
  ABANDON = T.let(T.unsafe(nil), Integer)
end
