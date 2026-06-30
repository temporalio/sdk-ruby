# typed: true

class Temporalio::Worker::WorkflowExecutor::ThreadPool < ::Temporalio::Worker::WorkflowExecutor
  extend T::Sig

  sig { returns(Temporalio::Worker::WorkflowExecutor::ThreadPool) }
  def self.default; end

  sig { params(max_threads: Integer, thread_pool: Temporalio::Worker::ThreadPool).void }
  def initialize(max_threads: T.unsafe(nil), thread_pool: T.unsafe(nil)); end
end

class Temporalio::Worker::WorkflowExecutor::ThreadPool::DeadlockError < ::Exception
  include Temporalio::Internal::WorkflowTaskFailureError
end
