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

      # TODO: Add timeout
      def result(follow_runs: true)
        client_impl.await_workflow_result(id, result_run_id, follow_runs)
      end

      def describe
        input = Interceptor::Client::DescribeWorkflowInput.new(id: id, run_id: run_id)

        client_impl.describe_workflow(input)
      end

      def cancel(reason = nil)
        input = Interceptor::Client::CancelWorkflowInput.new(
          id: id,
          run_id: run_id,
          first_execution_run_id: first_execution_run_id,
          reason: reason,
        )

        client_impl.cancel_workflow(input)
      end

      def query(query, *args, reject_condition: Workflow::QueryRejectCondition::NONE)
        input = Interceptor::Client::QueryWorkflowInput.new(
          id: id,
          run_id: run_id,
          query: query,
          args: args,
          reject_condition: reject_condition,
          headers: {},
        )

        client_impl.query_workflow(input)
      end

      def signal(signal, *args)
        input = Interceptor::Client::SignalWorkflowInput.new(
          id: id,
          run_id: run_id,
          signal: signal,
          args: args,
          headers: {},
        )

        client_impl.signal_workflow(input)
      end

      def terminate(reason = nil, args = nil)
        input = Interceptor::Client::TerminateWorkflowInput.new(
          id: id,
          run_id: run_id,
          first_execution_run_id: first_execution_run_id,
          reason: reason,
          args: args,
        )

        client_impl.terminate_workflow(input)
      end

      private

      attr_reader :client_impl
    end
  end
end
