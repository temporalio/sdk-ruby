# frozen_string_literal: true

require 'temporalio/worker/workflow_executor/thread_pool'

module Temporalio
  class Worker
    # Workflow executor that executes workflow tasks. Unlike {ActivityExecutor}, this class is not meant for user
    # implementation. The only implementation that is currently accepted is {WorkflowExecutor::ThreadPool}.
    class WorkflowExecutor
      # @!visibility private
      def initialize
        raise 'Cannot create custom executors'
      end

      # @!visibility private
      def _validate_worker(workflow_worker, worker_state)
        raise NotImplementedError
      end

      # @!visibility private
      def _activate(activation, worker_state, &)
        raise NotImplementedError
      end
    end
  end
end
