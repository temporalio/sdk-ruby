# typed: true

class Temporalio::Worker::ThreadPool
  extend T::Sig

  sig { returns(Temporalio::Worker::ThreadPool) }
  def self.default; end

  sig { params(max_threads: T.nilable(Integer), idle_timeout: Float).void }
  def initialize(max_threads: T.unsafe(nil), idle_timeout: T.unsafe(nil)); end

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
