require 'temporal/interceptor/client'
require 'temporal/workflow/query_reject_condition'

module Temporal
  class Client
    # Handle for interacting with a workflow.
    #
    # This is usually created via {Temporal::Client#workflow_handle} or returned
    # from {Temporal::Client#start_workflow}.
    class WorkflowHandle
      # @return [String] ID for the workflow.
      attr_reader :id

      # Run ID used for {#signal} and {#query} calls if present to ensure the query or signal happen
      # on this exact run.
      #
      # This is only created via {Temporal::Client#workflow_handle}.
      # {Temporal::Client#start_workflow} will not set this value.
      #
      # This cannot be mutated. If a different run ID is needed, {Temporal::Client#workflow_handle}
      # must be used instead.
      #
      # @return [String]
      attr_reader :run_id

      # Run ID used for {#result} calls if present to ensure result is for a workflow starting from
      # this run.
      #
      # When this handle is created via {Temporal::Client#workflow_handle}, this is the same as
      # `:run_id`. When this handle is created via {Temporal::Client#start_workflow}, this value
      # will be the resulting run ID.
      #
      # This cannot be mutated. If a different run ID is needed, {Temporal::Client#workflow_handle}
      # must be used instead.
      #
      # @return [String]
      attr_reader :result_run_id

      # Run ID used for {#cancel} and {#terminate} calls if present to ensure the cancel and
      # terminate happen for a workflow ID started with this run ID.
      #
      # This can be set when using {Temporal::Client#workflow_handle}. When
      # {Temporal::Client#start_workflow} is called without a start signal, this is set to the
      # resulting run.
      #
      # This cannot be mutated. If a different first execution run ID is needed,
      # {Temporal::Client#workflow_handle} must be used instead.
      #
      # @return [String]
      attr_reader :first_execution_run_id

      def initialize(client_impl, id, run_id: nil, result_run_id: nil, first_execution_run_id: nil)
        @client_impl = client_impl
        @id = id
        @run_id = run_id
        @result_run_id = result_run_id
        @first_execution_run_id = first_execution_run_id
      end

      # Wait for result of the workflow.
      #
      # This will use {#result_run_id} if present to base the result on. To use another run ID,
      # a new handle must be created via {Temporal::Client#workflow_handle}.
      #
      # @param follow_runs [Bool] If true (default), workflow runs will be continually fetched,
      #   until the most recent one is found. If false, the first result is used.
      # @param rpc_metadata [Hash<String, String>] Headers used on the RPC call.
      #   Keys here override client-level RPC metadata keys.
      # @param rpc_timeout [Integer] Optional RPC deadline to set for each RPC call. Note, this is
      #   the timeout for each history RPC call not this overall function.
      #
      # @return [any] Result of the workflow after being converted by the data converter.
      #
      # @raise [Temporal::Error::WorkflowFailure] Workflow failed, was cancelled, was terminated, or
      #   timed out. Use the {Temporal::Error::WorkflowFailure#cause} to see the underlying reason.
      # @raise [StandardError] Other possible failures during result fetching.
      def result(follow_runs: true, rpc_metadata: {}, rpc_timeout: nil)
        client_impl.await_workflow_result(id, result_run_id, follow_runs, rpc_metadata, rpc_timeout)
      end

      # Get workflow details.
      #
      # This will get details for {#run_id} if present. To use a different run ID, create a new
      # handle with via {Temporal::Client#workflow_handle}.
      #
      # @note Handles created as a result of {Temporal::Client#start_workflow} will describe the
      #   latest workflow with the same workflow ID even if it is unrelated to the started workflow.
      #
      # @param rpc_metadata [Hash<String, String>] Headers used on the RPC call.
      #   Keys here override client-level RPC metadata keys.
      # @param rpc_timeout [Integer] Optional RPC deadline to set for each RPC call. Note, this is
      #   the timeout for each history RPC call not this overall function.
      #
      # @return [Temporal::Workflow::ExecutionInfo] Workflow details.
      #
      # @raise [Temporal::Error::RPCError] Workflow details could not be fetched.
      def describe(rpc_metadata: {}, rpc_timeout: nil)
        input = Interceptor::Client::DescribeWorkflowInput.new(
          id: id,
          run_id: run_id,
          rpc_metadata: rpc_metadata,
          rpc_timeout: rpc_timeout,
        )

        client_impl.describe_workflow(input)
      end

      # Cancel the workflow.
      #
      # This will issue a cancellation for {#run_id} if present. This call will make sure to use the
      # run chain starting from {#first_execution_run_id} if present. To create handles with these
      # values, use {Temporal::Client#workflow_handle}.
      #
      # @note Handles created as a result of {Temporal::Client#start_workflow} with a start signal
      #   will cancel the latest workflow with the same workflow ID even if it is unrelated to the
      #   started workflow.
      #
      # @param reason [String] A reason for workflow cancellation.
      # @param rpc_metadata [Hash<String, String>] Headers used on the RPC call.
      #   Keys here override client-level RPC metadata keys.
      # @param rpc_timeout [Integer] Optional RPC deadline to set for each RPC call.
      #
      # @raise [Temporal::Error::RPCError] Workflow could not be cancelled.
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

      # Query the workflow.
      #
      # This will query for {#run_id} if present. To use a different run ID, create a new handle
      # with via {Temporal::Client#workflow_handle}.
      #
      # @note Handles created as a result of {Temporal::Client#start_workflow} will query the latest
      #   workflow with the same workflow ID even if it is unrelated to the started workflow.
      #
      # @param query [String, Symbol] Query function or name on the workflow.
      # @param args [any] Arguments to the query.
      # @param reject_condition [Symbol] Condition for rejecting the query. Refer to
      #   {Temporal::Workflow::QueryRejectCondition} for the list of allowed values.
      # @param rpc_metadata [Hash<String, String>] Headers used on the RPC call.
      #   Keys here override client-level RPC metadata keys.
      # @param rpc_timeout [Integer] Optional RPC deadline to set for each RPC call.
      #
      # @return [any] Result of the query.
      #
      # @raise [Temporal::Error] A query reject condition was satisfied.
      # @raise [Temporal::Error::RPCError] Workflow details could not be fetched.
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

      # Send a signal to the workflow.
      #
      # This will signal for {#run_id} if present. To use a different run ID, create a new handle
      # with via {Temporal::Client#workflow_handle}.
      #
      # @note Handles created as a result of {Temporal::Client#start_workflow} will signal the
      #   latest workflow with the same workflow ID even if it is unrelated to the started workflow.
      #
      # @param signal [String, Symbol] Signal function or name on the workflow.
      # @param args [any] Arguments to the signal.
      # @param rpc_metadata [Hash<String, String>] Headers used on the RPC call.
      #   Keys here override client-level RPC metadata keys.
      # @param rpc_timeout [Integer] Optional RPC deadline to set for each RPC call.
      #
      # @return [Temporal::Error::RPCError] Workflow could not be signalled.
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

      # Terminate the workflow.
      #
      # This will issue a termination for {#run_id} if present. This call will make sure to use the
      # run chain starting from {#first_execution_run_id} if present. To create handles with these
      # values, use {Temporal::Client#workflow_handle}.

      # @note Handles created as a result of {Temporal::Client#start_workflow} with a start signal
      #   will terminate the latest workflow with the same workflow ID even if it is unrelated to
      #   the started workflow.
      #
      # @param reason [String] A reason for workflow termination.
      # @param args [any] Details to store on the termination.
      # @param rpc_metadata [Hash<String, String>] Headers used on the RPC call.
      #   Keys here override client-level RPC metadata keys.
      # @param rpc_timeout [Integer] Optional RPC deadline to set for each RPC call.
      #
      # @raise [Temporal::Error::RPCError] Workflow could not be terminated.
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
