require 'forwardable'

module Temporalio
  module Testing
    class TimeSkippingHandle
      extend Forwardable

      # Proxy all the WorkflowHandle calls to the original handle except for :result
      def_delegators :handle, :id, :run_id, :result_run_id, :first_execution_run_id, :describe,
                     :cancel, :query, :signal, :terminate

      def initialize(handle, env)
        @handle = handle
        @env = env
      end

      def result(follow_runs: true, rpc_metadata: {}, rpc_timeout: nil)
        env.with_time_skipping do
          handle.result(
            follow_runs: follow_runs,
            rpc_metadata: rpc_metadata,
            rpc_timeout: rpc_timeout,
          )
        end
      end

      private

      attr_reader :handle, :env
    end
  end
end
