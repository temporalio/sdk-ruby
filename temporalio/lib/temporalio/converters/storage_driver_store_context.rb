# frozen_string_literal: true

require 'temporalio/cancellation'
require 'temporalio/converters/storage_driver_limiter'

module Temporalio
  module Converters
    StorageDriverStoreContext = Data.define(
      :target,
      :cancellation,
      :limiter,
      :namespace
    )

    # Context given to {StorageDriver#store}.
    #
    # @note WARNING: This API is experimental and may change in the future. Members may be added, so accept keyword
    #   arguments defensively if constructing this yourself.
    #
    # @!attribute [r] target
    #   @return [StorageDriverWorkflowInfo, StorageDriverActivityInfo, nil] The execution the payloads are being stored
    #     on behalf of, or nil when there is no associated execution.
    # @!attribute [r] cancellation
    #   @return [Cancellation] Cancellation for this store operation. The SDK does not cancel it yet. Drivers may still
    #     check it, so that they stop early once the SDK does.
    # @!attribute [r] namespace
    #   @return [String, nil] Namespace of the client or worker performing the store, or nil when it is not known.
    class StorageDriverStoreContext
      def initialize(target:, cancellation:, limiter: StorageDriverLimiter::UNBOUNDED, namespace: nil)
        super
      end
    end
  end
end
