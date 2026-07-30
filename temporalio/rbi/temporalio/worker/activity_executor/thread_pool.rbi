# typed: true

class Temporalio::Worker::ActivityExecutor::ThreadPool < ::Temporalio::Worker::ActivityExecutor
  extend T::Sig

  sig { returns(Temporalio::Worker::ActivityExecutor::ThreadPool) }
  def self.default; end

  sig { params(thread_pool: Temporalio::Worker::ThreadPool).void }
  def initialize(thread_pool = T.unsafe(nil)); end

  sig { params(defn: Temporalio::Activity::Definition::Info, block: T.proc.void).void }
  def execute_activity(defn, &block); end

  sig { returns(T.nilable(Temporalio::Activity::Context)) }
  def activity_context; end

  sig { params(defn: Temporalio::Activity::Definition::Info, context: T.nilable(Temporalio::Activity::Context)).void }
  def set_activity_context(defn, context); end
end
