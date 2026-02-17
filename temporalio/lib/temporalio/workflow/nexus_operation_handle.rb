# frozen_string_literal: true

module Temporalio
  module Workflow
    # Handle for interacting with a Nexus operation.
    #
    # This is created via {NexusClient#start_operation}, it is never instantiated directly.
    #
    # WARNING: Nexus support is experimental.
    class NexusOperationHandle
      # @!visibility private
      def initialize
        raise NotImplementedError, 'Cannot instantiate a Nexus operation handle directly'
      end

      # @return [String, nil] Operation token for async operations, nil for sync operations.
      def operation_token
        raise NotImplementedError
      end

      # @return [Object, nil] Hint for the result if any.
      def result_hint
        raise NotImplementedError
      end

      # Wait for the result.
      #
      # @param result_hint [Object, nil] Override the result hint, or if nil uses the one on the handle.
      # @return [Object] Result of the Nexus operation.
      #
      # @raise [Error::NexusOperationError] Operation failed with +cause+ as the cause.
      def result(result_hint: nil)
        raise NotImplementedError
      end
    end
  end
end
