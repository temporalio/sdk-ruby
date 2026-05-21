# frozen_string_literal: true

module Temporalio
  class Client
    # Handle for a standalone Nexus operation to perform actions on.
    #
    # This is created via {NexusClient#start_operation} or {Client#nexus_operation_handle}, it is never instantiated
    # directly.
    #
    # WARNING: Standalone Nexus operations are experimental.
    class NexusOperationHandle
      # @return [String] Operation ID.
      attr_reader :operation_id

      # @return [String, nil] Operation run ID if known.
      attr_reader :run_id

      # @!visibility private
      def initialize(client:, operation_id:, run_id:)
        @client = client
        @operation_id = operation_id
        @run_id = run_id
      end

      # Wait for the result of the operation.
      #
      # WARNING: Standalone Nexus operations are experimental.
      #
      # @param rpc_options [RPCOptions, nil] Advanced RPC options.
      # @return [Object, nil] Result of the operation.
      # @raise [Error::NexusOperationFailedError] Operation failed.
      # @raise [Error::RPCError] RPC error from call.
      def result(rpc_options: nil)
        @client._impl.poll_nexus_operation(
          Interceptor::PollNexusOperationInput.new(
            operation_id:,
            run_id:,
            rpc_options:
          )
        )
      end

      # Describe this operation.
      #
      # WARNING: Standalone Nexus operations are experimental.
      #
      # @param rpc_options [RPCOptions, nil] Advanced RPC options.
      # @return [Api::WorkflowService::V1::DescribeNexusOperationExecutionResponse] Operation description.
      # @raise [Error::RPCError] RPC error from call.
      def describe(rpc_options: nil)
        @client._impl.describe_nexus_operation(
          Interceptor::DescribeNexusOperationInput.new(
            operation_id:,
            run_id:,
            rpc_options:
          )
        )
      end

      # Request cancellation of this operation.
      #
      # WARNING: Standalone Nexus operations are experimental.
      #
      # @param reason [String, nil] Reason for cancellation.
      # @param rpc_options [RPCOptions, nil] Advanced RPC options.
      # @raise [Error::RPCError] RPC error from call.
      def cancel(reason: nil, rpc_options: nil)
        @client._impl.cancel_nexus_operation(
          Interceptor::CancelNexusOperationInput.new(
            operation_id:,
            run_id:,
            reason:,
            rpc_options:
          )
        )
      end

      # Terminate this operation.
      #
      # WARNING: Standalone Nexus operations are experimental.
      #
      # @param reason [String, nil] Reason for termination.
      # @param rpc_options [RPCOptions, nil] Advanced RPC options.
      # @raise [Error::RPCError] RPC error from call.
      def terminate(reason: nil, rpc_options: nil)
        @client._impl.terminate_nexus_operation(
          Interceptor::TerminateNexusOperationInput.new(
            operation_id:,
            run_id:,
            reason:,
            rpc_options:
          )
        )
      end
    end
  end
end
