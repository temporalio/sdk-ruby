# typed: true

class Temporalio::Internal::Worker::WorkflowInstance::IllegalCallTracer
  extend T::Sig

  sig { params(illegal_calls: T::Hash[String, Object]).returns(T::Hash[String, Object]) }
  def self.frozen_validated_illegal_calls(illegal_calls); end

  sig { params(illegal_calls: T::Hash[String, Object]).void }
  def initialize(illegal_calls); end

  sig { type_parameters(:T).params(block: T.proc.returns(T.type_parameter(:T))).returns(T.type_parameter(:T)) }
  def enable(&block); end

  sig { type_parameters(:T).params(block: T.proc.returns(T.type_parameter(:T))).returns(T.type_parameter(:T)) }
  def disable_temporarily(&block); end
end
