# typed: true

# Sorbet RBI types for the Temporal Ruby SDK.
# This file was split from rbi/temporalio.rbi by extra/split_rbi.rb.

class Temporalio::Worker::ActivityExecutor
  extend T::Sig

  sig { returns(T::Hash[Symbol, Temporalio::Worker::ActivityExecutor]) }
  def self.defaults; end

  sig { params(defn: Temporalio::Activity::Definition::Info).void }
  def initialize_activity(defn); end

  sig { params(defn: Temporalio::Activity::Definition::Info, block: T.proc.void).void }
  def execute_activity(defn, &block); end

  sig { returns(T.nilable(Temporalio::Activity::Context)) }
  def activity_context; end

  sig { params(defn: Temporalio::Activity::Definition::Info, context: T.nilable(Temporalio::Activity::Context)).void }
  def set_activity_context(defn, context); end
end
