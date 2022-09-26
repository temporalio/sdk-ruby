require 'temporal/interceptor/client'
require 'temporal/workflow/query_reject_condition'

module Temporal
  class Client
    class WorkflowHandle
      attr_reader :id, :run_id, :result_run_id, :first_execution_run_id

      def initialize(client_impl, id, run_id: nil, result_run_id: nil, first_execution_run_id: nil)
        @client_impl = client_impl
        @id = id
        @run_id = run_id
        @result_run_id = result_run_id
        @first_execution_run_id = first_execution_run_id
      end

      def result(follow_runs: true, rpc_metadata: {}, rpc_timeout: nil)
        client_impl.await_workflow_result(id, result_run_id, follow_runs, rpc_metadata, rpc_timeout)
      end

      def describe(rpc_metadata: {}, rpc_timeout: nil)
        input = Interceptor::Client::DescribeWorkflowInput.new(
          id: id,
          run_id: run_id,
          rpc_metadata: rpc_metadata,
          rpc_timeout: rpc_timeout,
        )

        client_impl.describe_workflow(input)
      end

      def cancel(reason = nil, rpc_metadata: {}, rpc_timeout: nil)
        input = Interceptor::Client::CancelWorkflowInput.new(
          id: id,
          run_id: run_id,
          first_execution_run_id: first_execution_run_id,
          reason: reason,
          rpc_metadata: rpc_metadata,
          rpc_timeout: rpc_timeout,
        )

        client_impl.cancel_workflow(input)
      end

      def query(
        query,
        *args,
        reject_condition: Workflow::QueryRejectCondition::NONE,
        rpc_metadata: {},
        rpc_timeout: nil
      )
        input = Interceptor::Client::QueryWorkflowInput.new(
          id: id,
          run_id: run_id,
          query: query,
          args: args,
          reject_condition: reject_condition,
          headers: {},
          rpc_metadata: rpc_metadata,
          rpc_timeout: rpc_timeout,
        )

        client_impl.query_workflow(input)
      end

      def signal(signal, *args, rpc_metadata: {}, rpc_timeout: nil)
        input = Interceptor::Client::SignalWorkflowInput.new(
          id: id,
          run_id: run_id,
          signal: signal,
          args: args,
          headers: {},
          rpc_metadata: rpc_metadata,
          rpc_timeout: rpc_timeout,
        )

        client_impl.signal_workflow(input)
      end

      def terminate(reason = nil, args = nil, rpc_metadata: {}, rpc_timeout: nil)
        input = Interceptor::Client::TerminateWorkflowInput.new(
          id: id,
          run_id: run_id,
          first_execution_run_id: first_execution_run_id,
          reason: reason,
          args: args,
          rpc_metadata: rpc_metadata,
          rpc_timeout: rpc_timeout,
        )

        client_impl.terminate_workflow(input)
      end

      private

      attr_reader :client_impl
    end
  end
end
