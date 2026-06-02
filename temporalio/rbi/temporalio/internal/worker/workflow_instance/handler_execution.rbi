# typed: true

class Temporalio::Internal::Worker::WorkflowInstance::HandlerExecution
  extend T::Sig

  sig { returns(String) }
  attr_reader :name

  sig { returns(T.nilable(String)) }
  attr_reader :update_id

  sig { returns(Integer) }
  attr_reader :unfinished_policy

  sig { params(name: String, update_id: T.nilable(String), unfinished_policy: Integer).void }
  def initialize(name:, update_id:, unfinished_policy:); end
end
