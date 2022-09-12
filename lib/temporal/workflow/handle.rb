module Temporal
  class Workflow
    class Handle
      attr_reader :id, :run_id

      def initialize(client, id, run_id = nil)
        @client = client
        @id = id
        @run_id = run_id
      end

      def result(follow_runs: false, timeout: nil)
        client.await_workflow_result(id, run_id, timeout: timeout)
      end

      def describe
        client.describe_workflow(id, run_id)
      end

      def cancel
        client.cancel_workflow(id, run_id)
      end

      def query(query)
        client.query_workflow(id, run_id, query: query)
      end

      def signal(signal, input = nil)
        client.signal_workflow(id, run_id, signal: signal, input: input)
      end

      def terminate(reason = nil, details = nil)
        client.terminate_workflow(id, run_id, reason: reason, details: details)
      end

      private

      attr_reader :client
    end
  end
end
