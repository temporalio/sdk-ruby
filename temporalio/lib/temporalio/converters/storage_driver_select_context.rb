# frozen_string_literal: true

require 'temporalio/cancellation'

module Temporalio
  module Converters
    StorageDriverSelectContext = Data.define(
      :target,
      :cancellation
    )

    # Context given to the driver selector.
    #
    # @note WARNING: This API is experimental and may change in the future. Members may be added, so accept keyword
    #   arguments defensively if constructing this yourself.
    #
    # @!attribute [r] target
    #   @return [StorageDriverWorkflowInfo, StorageDriverActivityInfo, nil] The execution the payload is being stored
    #     on behalf of, or nil when there is no associated execution.
    # @!attribute [r] cancellation
    #   @return [Cancellation] Cancelled when the SDK abandons the operation this selection is part of.
    #
    # @!visibility private
    class StorageDriverSelectContext; end # rubocop:disable Lint/EmptyClass
  end
end
