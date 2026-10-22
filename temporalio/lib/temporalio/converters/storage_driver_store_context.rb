# frozen_string_literal: true

require 'temporalio/cancellation'
require 'temporalio/converters/storage_driver_limiter'

module Temporalio
  module Converters
    StorageDriverStoreContext = Data.define(
      :target,
      :cancellation,
      :limiter
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
    #   @return [Cancellation] Cancelled when the SDK abandons this store operation.
    # @!attribute [r] limiter
    #   @return [StorageDriverLimiter] Limiter for this driver's store requests.
    #
    # @!visibility private
    class StorageDriverStoreContext; end # rubocop:disable Lint/EmptyClass
  end
end
