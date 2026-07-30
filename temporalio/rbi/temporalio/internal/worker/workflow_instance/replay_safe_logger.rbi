# typed: true

class Temporalio::Internal::Worker::WorkflowInstance::ReplaySafeLogger < Temporalio::ScopedLogger
  extend T::Sig

  sig { params(logger: Logger, instance: Temporalio::Internal::Worker::WorkflowInstance).void }
  def initialize(logger:, instance:); end

  sig { type_parameters(:T).params(block: T.proc.returns(T.type_parameter(:T))).returns(T.type_parameter(:T)) }
  def replay_safety_disabled(&block); end
end
