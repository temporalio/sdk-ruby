# frozen_string_literal: true

require 'securerandom'

module Temporalio
  class Client
    # Client for starting and managing standalone Nexus operations.
    #
    # This is created via {Client.create_nexus_client}, it is never instantiated directly.
    #
    # WARNING: Standalone Nexus operations are experimental.
    class NexusClient
      # @return [String] Endpoint name for this client.
      attr_reader :endpoint

      # @return [String] Service name for this client.
      attr_reader :service

      # @!visibility private
      def initialize(client:, endpoint:, service:)
        @client = client
        @endpoint = endpoint
        @service = service
      end

      # Start a Nexus operation and return a handle.
      #
      # WARNING: Standalone Nexus operations are experimental.
      #
      # @param operation [String, Symbol] Operation name.
      # @param input [Object, nil] Input for the operation.
      # @param id [String] Unique identifier for the operation.
      # @param schedule_to_close_timeout [Float, nil] Total timeout for the operation in seconds.
      # @param schedule_to_start_timeout [Float, nil] Timeout in seconds for the operation to start executing. If the
      #   operation has not started within this window, a SCHEDULE_TO_START timeout error is raised.
      # @param start_to_close_timeout [Float, nil] Timeout in seconds for an async operation to complete after it has
      #   started. If the operation does not complete within this window, a START_TO_CLOSE timeout error is raised.
      # @param id_reuse_policy [NexusOperationIDReusePolicy] How already-existing IDs are treated.
      # @param id_conflict_policy [NexusOperationIDConflictPolicy] How already-running operations of the same ID are
      #   treated.
      # @param search_attributes [SearchAttributes, nil] Search attributes for the operation.
      # @param nexus_header [Hash{String => String}] Headers to attach to the Nexus request.
      # @param static_summary [String, nil] Summary for the operation (appears in UI/CLI).
      # @param rpc_options [RPCOptions, nil] Advanced RPC options.
      #
      # @return [NexusOperationHandle] Handle to the started operation.
      # @raise [Error::NexusOperationAlreadyStartedError] Operation already exists.
      # @raise [Error::RPCError] RPC error from call.
      def start_operation(
        operation,
        input = nil,
        id:,
        schedule_to_close_timeout: nil,
        schedule_to_start_timeout: nil,
        start_to_close_timeout: nil,
        id_reuse_policy: NexusOperationIDReusePolicy::ALLOW_DUPLICATE,
        id_conflict_policy: NexusOperationIDConflictPolicy::FAIL,
        search_attributes: nil,
        nexus_header: {},
        static_summary: nil,
        rpc_options: nil
      )
        @client._impl.start_nexus_operation(
          Interceptor::StartNexusOperationInput.new(
            endpoint:,
            service:,
            operation: operation.to_s,
            input:,
            operation_id: id,
            schedule_to_close_timeout:,
            schedule_to_start_timeout:,
            start_to_close_timeout:,
            id_reuse_policy:,
            id_conflict_policy:,
            search_attributes:,
            nexus_header:,
            static_summary:,
            headers: {},
            rpc_options:
          )
        )
      end

      # Start a Nexus operation and wait for its result. This is a shortcut for {start_operation} +
      # {NexusOperationHandle.result}.
      #
      # WARNING: Standalone Nexus operations are experimental.
      #
      # @param operation [String, Symbol] Operation name.
      # @param input [Object, nil] Input for the operation.
      # @param id [String] Unique identifier for the operation.
      # @param schedule_to_close_timeout [Float, nil] Total timeout for the operation in seconds.
      # @param schedule_to_start_timeout [Float, nil] Timeout in seconds for the operation to start executing.
      # @param start_to_close_timeout [Float, nil] Timeout in seconds for an async operation to complete after started.
      # @param id_reuse_policy [NexusOperationIDReusePolicy] How already-existing IDs are treated.
      # @param id_conflict_policy [NexusOperationIDConflictPolicy] How already-running operations of the same ID are
      #   treated.
      # @param search_attributes [SearchAttributes, nil] Search attributes for the operation.
      # @param nexus_header [Hash{String => String}] Headers to attach to the Nexus request.
      # @param static_summary [String, nil] Summary for the operation (appears in UI/CLI).
      # @param rpc_options [RPCOptions, nil] Advanced RPC options.
      #
      # @return [Object, nil] Result of the operation.
      # @raise [Error::NexusOperationAlreadyStartedError] Operation already exists.
      # @raise [Error::NexusOperationFailedError] Operation failed.
      # @raise [Error::RPCError] RPC error from call.
      def execute_operation(
        operation,
        input = nil,
        id:,
        schedule_to_close_timeout: nil,
        schedule_to_start_timeout: nil,
        start_to_close_timeout: nil,
        id_reuse_policy: NexusOperationIDReusePolicy::ALLOW_DUPLICATE,
        id_conflict_policy: NexusOperationIDConflictPolicy::FAIL,
        search_attributes: nil,
        nexus_header: {},
        static_summary: nil,
        rpc_options: nil
      )
        start_operation(
          operation,
          input,
          id:,
          schedule_to_close_timeout:,
          schedule_to_start_timeout:,
          start_to_close_timeout:,
          id_reuse_policy:,
          id_conflict_policy:,
          search_attributes:,
          nexus_header:,
          static_summary:,
          rpc_options:
        ).result(rpc_options:)
      end
    end
  end
end
