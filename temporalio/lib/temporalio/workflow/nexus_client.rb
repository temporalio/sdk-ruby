# frozen_string_literal: true

module Temporalio
  module Workflow
    # Client for executing Nexus operations from workflows.
    #
    # This is created via {Workflow.create_nexus_client}, it is never instantiated directly.
    #
    # WARNING: Nexus support is experimental.
    class NexusClient
      # @!visibility private
      def initialize
        raise NotImplementedError, 'Cannot instantiate a Nexus client directly'
      end

      # @return [String] Endpoint name for this client.
      def endpoint
        raise NotImplementedError
      end

      # @return [String] Service name for this client.
      def service
        raise NotImplementedError
      end

      # Start a Nexus operation and return a handle.
      #
      # @param operation [Symbol, String] Operation name.
      # @param arg [Object] Argument for the operation.
      # @param schedule_to_close_timeout [Float, nil] Total timeout for the operation in seconds.
      # @param cancellation_type [NexusOperationCancellationType] How the operation will react to cancellation.
      # @param summary [String, nil] Optional summary for the operation (appears in UI/CLI).
      # @param cancellation [Cancellation] Cancellation for the operation.
      # @param arg_hint [Object, nil] Converter hint for the argument.
      # @param result_hint [Object, nil] Converter hint for the result.
      # @return [NexusOperationHandle] Handle to the started operation.
      def start_operation(
        operation,
        arg,
        schedule_to_close_timeout: nil,
        cancellation_type: NexusOperationCancellationType::WAIT_CANCELLATION_COMPLETED,
        summary: nil,
        cancellation: Workflow.cancellation,
        arg_hint: nil,
        result_hint: nil
      )
        raise NotImplementedError
      end

      # Execute a Nexus operation and wait for the result.
      #
      # This is a convenience method that calls {#start_operation} and immediately waits for the result.
      #
      # @param operation [Symbol, String] Operation name.
      # @param arg [Object] Argument for the operation.
      # @param schedule_to_close_timeout [Float, nil] Total timeout for the operation in seconds.
      # @param cancellation_type [NexusOperationCancellationType] How the operation will react to cancellation.
      # @param summary [String, nil] Optional summary for the operation (appears in UI/CLI).
      # @param cancellation [Cancellation] Cancellation for the operation.
      # @param arg_hint [Object, nil] Converter hint for the argument.
      # @param result_hint [Object, nil] Converter hint for the result.
      # @return [Object] Result of the operation.
      # @raise [Error::NexusOperationError] Operation failed.
      def execute_operation(
        operation,
        arg,
        schedule_to_close_timeout: nil,
        cancellation_type: NexusOperationCancellationType::WAIT_CANCELLATION_COMPLETED,
        summary: nil,
        cancellation: Workflow.cancellation,
        arg_hint: nil,
        result_hint: nil
      )
        start_operation(
          operation, arg, schedule_to_close_timeout:, cancellation_type:, summary:, cancellation:,
                          arg_hint:, result_hint:
        ).result
      end
    end
  end
end
