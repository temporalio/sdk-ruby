# typed: true

# Sorbet RBI types for the Temporal Ruby SDK.
# This file was split from rbi/temporalio.rbi by extra/split_rbi.rb.

module Temporalio::Worker::Plugin
  extend T::Sig

  sig { returns(String) }
  def name; end

  sig { params(options: Temporalio::Worker::Options).returns(Temporalio::Worker::Options) }
  def configure_worker(options); end

  sig { params(options: Temporalio::Worker::Plugin::RunWorkerOptions, next_call: T.proc.params(arg0: Temporalio::Worker::Plugin::RunWorkerOptions).returns(T.anything)).returns(T.anything) }
  def run_worker(options, next_call); end

  sig { params(options: Temporalio::Worker::WorkflowReplayer::Options).returns(Temporalio::Worker::WorkflowReplayer::Options) }
  def configure_workflow_replayer(options); end

  sig { params(options: Temporalio::Worker::Plugin::WithWorkflowReplayWorkerOptions, next_call: T.proc.params(arg0: Temporalio::Worker::Plugin::WithWorkflowReplayWorkerOptions).returns(T.anything)).returns(T.anything) }
  def with_workflow_replay_worker(options, next_call); end
end

class Temporalio::Worker::Plugin::RunWorkerOptions < ::Data
  extend T::Sig

  sig { returns(Temporalio::Worker) }
  def worker; end

  sig { returns(Temporalio::Cancellation) }
  def cancellation; end

  sig { returns(T::Array[T.any(String, Integer)]) }
  def shutdown_signals; end

  sig { returns(T.nilable(Exception)) }
  def raise_in_block_on_shutdown; end

  sig { params(kwargs: T.untyped).returns(Temporalio::Worker::Plugin::RunWorkerOptions) }
  def with(**kwargs); end
end

class Temporalio::Worker::Plugin::WithWorkflowReplayWorkerOptions < ::Data
  extend T::Sig

  sig { returns(Temporalio::Worker::WorkflowReplayer::ReplayWorker) }
  def worker; end

  sig { params(kwargs: T.untyped).returns(Temporalio::Worker::Plugin::WithWorkflowReplayWorkerOptions) }
  def with(**kwargs); end
end
