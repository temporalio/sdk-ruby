# typed: true

class Temporalio::Internal::Worker::WorkflowInstance::HandlerExecution
  extend T::Sig

  sig { returns(String) }
  def name; end

  sig { returns(T.nilable(String)) }
  def update_id; end

  sig { returns(Integer) }
  def unfinished_policy; end

  sig { params(name: String, update_id: T.nilable(String), unfinished_policy: Integer).void }
  def initialize(name:, update_id:, unfinished_policy:); end
end
