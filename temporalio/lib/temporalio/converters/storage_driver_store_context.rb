# frozen_string_literal: true

require 'temporalio/cancellation'

module Temporalio
  module Converters
    # Context given to {StorageDriver#store}.
    #
    # @note WARNING: This API is experimental and may change in the future. Members may be added, so accept keyword
    #   arguments defensively if constructing this yourself.
    #
    # @!visibility private
    class StorageDriverStoreContext
      # @return [StorageDriverWorkflowInfo, StorageDriverActivityInfo, nil] The execution the payloads are being stored
      #   on behalf of, or nil when there is no associated execution.
      attr_reader :target

      # @return [Cancellation] Cancelled when the SDK abandons this store operation.
      attr_reader :cancellation

      # Create a store context.
      #
      # @param target [StorageDriverWorkflowInfo, StorageDriverActivityInfo, nil] Execution being stored for.
      # @param cancellation [Cancellation] Cancellation for the operation.
      def initialize(target:, cancellation:)
        @target = target
        @cancellation = cancellation
      end
    end
  end
end
