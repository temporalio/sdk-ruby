# typed: true

class Temporalio::Workflow::NexusOperationHandle
  extend T::Sig

  sig { returns(T.nilable(String)) }
  def operation_token; end

  sig { returns(T.nilable(Object)) }
  def result_hint; end

  sig { params(result_hint: T.nilable(Object)).returns(T.nilable(Object)) }
  def result(result_hint: T.unsafe(nil)); end
end
