# typed: true

class Temporalio::Internal::Worker::WorkflowInstance::ExternallyImmutableHash < Hash
  extend T::Sig

  sig { params(initial_hash: T::Hash[Object, Object]).void }
  def initialize(initial_hash); end

  sig { params(block: T.proc.params(arg0: T::Hash[Object, Object]).void).void }
  def _update(&block); end

  sig { returns(T::Hash[Object, Object]) }
  def __getobj__; end

  sig { params(obj: T::Hash[Object, Object]).void }
  def __setobj__(obj); end
end
