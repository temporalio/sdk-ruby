# typed: true

class Temporalio::Worker::ThreadPool
  extend T::Sig

  sig { returns(Temporalio::Worker::ThreadPool) }
  def self.default; end

  sig do
    params(
      max_threads: T.nilable(Integer),
      idle_timeout: Float,
      thread_context: Temporalio::Worker::ThreadPool::ThreadContext
    ).void
  end
  def initialize(max_threads: T.unsafe(nil), idle_timeout: T.unsafe(nil), thread_context: T.unsafe(nil)); end

  sig { params(block: T.proc.void).void }
  def execute(&block); end

  sig { returns(Integer) }
  def largest_length; end

  sig { returns(Integer) }
  def scheduled_task_count; end

  sig { returns(Integer) }
  def completed_task_count; end

  sig { returns(Integer) }
  def active_count; end

  sig { returns(Integer) }
  def length; end

  sig { returns(Integer) }
  def queue_length; end

  sig { void }
  def shutdown; end

  sig { void }
  def kill; end
end

class Temporalio::Worker::ThreadPool::ThreadContext
  extend T::Sig

  sig { returns(Temporalio::Worker::ThreadPool::ThreadContext) }
  def self.default; end

  sig { returns(T::Boolean) }
  attr_reader :restart_worker

  sig { params(restart_worker: T::Boolean).void }
  def initialize(restart_worker: T.unsafe(nil)); end

  sig { params(block: T.proc.void).void }
  def call(&block); end
end

class Temporalio::Worker::ThreadPool::ThreadContext::NoOp < Temporalio::Worker::ThreadPool::ThreadContext
  extend T::Sig

  sig { params(block: T.proc.void).void }
  def call(&block); end
end
