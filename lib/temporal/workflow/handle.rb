module Temporal
  class Workflow
    class Handle
      attr_reader :id, :run_id

      def initialize(client, id, run_id = nil)
        @client = client
        @id = id
        @run_id = run_id
      end

      # TODO: Add timeout and follow_runs
      def result
        client.await_workflow_result(id, run_id)
      end

      def describe
        client.describe_workflow(id, run_id)
      end

      def cancel(reason = nil)
        client.cancel_workflow(id, run_id, reason: reason)
      end

      def query(query, *args)
        client.query_workflow(id, run_id, query: query, args: args)
      end

      def signal(signal, *args)
        client.signal_workflow(id, run_id, signal: signal, args: args)
      end

      def terminate(reason = nil, args = nil)
        client.terminate_workflow(id, run_id, reason: reason, args: args)
      end

      private

      attr_reader :client
    end
  end
end
