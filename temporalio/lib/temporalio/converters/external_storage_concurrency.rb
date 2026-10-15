# frozen_string_literal: true

module Temporalio
  module Converters
    ExternalStorageConcurrency = Data.define(
      :max_driver_operations,
      :max_operations_per_message
    )

    # Limits on how many external storage requests may be in flight at once. Set on
    # {ExternalStorage#concurrency}.
    #
    # @note WARNING: This API is experimental and may change in the future.
    #
    # @!attribute [r] max_driver_operations
    #   @return [Integer] Maximum requests in flight at once across every driver registered on the owning
    #     {ExternalStorage}. Each worker and each client gets its own budget of this size.
    # @!attribute [r] max_operations_per_message
    #   @return [Integer] Maximum requests in flight at once on behalf of a single message, such as one workflow task
    #     activation, activity task, Nexus operation, or client request. Every message gets its own budget of this
    #     size, which stops a message carrying many large payloads from starving the rest.
    #
    # @!visibility private
    class ExternalStorageConcurrency
      # Shared with every other SDK.
      DEFAULT_MAX_DRIVER_OPERATIONS = 64

      # Shared with every other SDK.
      DEFAULT_MAX_OPERATIONS_PER_MESSAGE = 8

      # Create concurrency limits.
      #
      # @param max_driver_operations [Integer] Maximum requests in flight across the configuration.
      # @param max_operations_per_message [Integer] Maximum requests in flight for one message.
      def initialize(
        max_driver_operations: DEFAULT_MAX_DRIVER_OPERATIONS,
        max_operations_per_message: DEFAULT_MAX_OPERATIONS_PER_MESSAGE
      )
        # A budget of zero would stop every storage operation rather than disabling the limit, so it is rejected
        # here instead of deadlocking the first offload.
        unless max_driver_operations.is_a?(Integer) && max_driver_operations >= 1
          raise ArgumentError, 'max_driver_operations must be an Integer of at least 1'
        end
        unless max_operations_per_message.is_a?(Integer) && max_operations_per_message >= 1
          raise ArgumentError, 'max_operations_per_message must be an Integer of at least 1'
        end

        super
      end
    end
  end
end
