module Temporal
  class Client
    class WorkflowHandle
      attr_reader :id, :run_id, :result_run_id, :first_execution_run_id

      def initialize(client, id, run_id: nil, result_run_id: nil, first_execution_run_id: nil)
        @client = client
        @id = id
        @run_id = run_id
        @result_run_id = result_run_id
        @first_execution_run_id = first_execution_run_id
      end

      # TODO: Add timeout and follow_runs
      def result
        client.await_workflow_result(id, result_run_id)
      end

      def describe
        client.describe_workflow(id, run_id)
      end

      def cancel(reason = nil)
        client.cancel_workflow(
          id,
          run_id: run_id,
          reason: reason,
          first_execution_run_id: first_execution_run_id,
        )
      end

      def query(query, *args)
        client.query_workflow(id, run_id, query: query, args: args)
      end

      def signal(signal, *args)
        client.signal_workflow(id, run_id, signal: signal, args: args)
      end

      def terminate(reason = nil, args = nil)
        client.terminate_workflow(
          id,
          run_id: run_id,
          reason: reason,
          args: args,
          first_execution_run_id: first_execution_run_id,
        )
      end

      private

      attr_reader :client
    end
  end
end
