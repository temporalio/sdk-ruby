# frozen_string_literal: true

module Temporalio
  class Worker
    # Plugin mixin to include for configuring workers and workflow replayers, and intercepting the running of them.
    #
    # This is a low-level implementation that requires abstract methods herein to be implemented. Many implementers may
    # prefer {SimplePlugin} which includes this.
    #
    # WARNING: Plugins are experimental.
    module Plugin
      RunWorkerOptions = Data.define(
        :worker,
        :cancellation,
        :shutdown_signals,
        :raise_in_block_on_shutdown
      )

      # Options for {run_worker}.
      #
      # The options contain the worker and some other options from {Worker#run}/{Worker.run_all}. Unlike other memebers
      # in this class, mutating the worker member before invoking the next call in the chain has no effect.
      #
      # @note Additional required attributes of this class may be added in the future. Users should never instantiate
      #   this class, but instead use `with` on it in {run_worker}.
      class RunWorkerOptions; end # rubocop:disable Lint/EmptyClass

      WithWorkflowReplayWorkerOptions = Data.define(
        :worker
      )

      # Options for {with_workflow_replay_worker}.
      #
      # @note Additional required attributes of this class may be added in the future. Users should never instantiate
      #   this class, but instead use `with` on it in {with_workflow_replay_worker}.
      #
      # @!attribute worker
      #   @return [WorkflowReplayer::ReplayWorker] Replay worker.
      class WithWorkflowReplayWorkerOptions; end # rubocop:disable Lint/EmptyClass

      # @abstract
      # @return [String] Name of the plugin.
      def name
        raise NotImplementedError
      end

      # Configure a worker.
      #
      # @abstract
      # @param options [Options] Current immutable options set.
      # @return [Options] Options to use, possibly updated from original.
      def configure_worker(options)
        raise NotImplementedError
      end

      # Run a worker.
      #
      # @abstract
      # @param options [RunWorkerOptions] Current immutable options set.
      # @param next_call [Proc] Proc for the next plugin in the chain to call. It accepts the options and returns an
      #   arbitrary object that should also be returned from this method.
      # @return [Object] Result of next_call.
      def run_worker(options, next_call)
        raise NotImplementedError
      end

      # Configure a workflow replayer.
      #
      # @abstract
      # @param options [WorkflowReplayer::Options] Current immutable options set.
      # @return [WorkflowReplayer::Options] Options to use, possibly updated from original.
      def configure_workflow_replayer(options)
        raise NotImplementedError
      end

      # Run a replay worker.
      #
      # @abstract
      # @param options [WithWorkflowReplayWorkerOptions] Current immutable options set.
      # @param next_call [Proc] Proc for the next plugin in the chain to call. It accepts the options and returns an
      #   arbitrary object that should also be returned from this method.
      # @return [Object] Result of next_call.
      def with_workflow_replay_worker(options, next_call)
        raise NotImplementedError
      end
    end
  end
end
