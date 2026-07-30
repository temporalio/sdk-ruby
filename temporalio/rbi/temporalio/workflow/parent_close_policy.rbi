# typed: true

module Temporalio::Workflow::ParentClosePolicy
  UNSPECIFIED = T.let(T.unsafe(nil), Integer)
  TERMINATE = T.let(T.unsafe(nil), Integer)
  ABANDON = T.let(T.unsafe(nil), Integer)
  REQUEST_CANCEL = T.let(T.unsafe(nil), Integer)
end
