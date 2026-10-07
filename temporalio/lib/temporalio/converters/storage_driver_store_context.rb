# frozen_string_literal: true

require 'temporalio/cancellation'

module Temporalio
  module Converters
    StorageDriverStoreContext = Data.define(
      :target,
      :cancellation
    )

    # Context given to {StorageDriver#store}.
    #
    # @note WARNING: This API is experimental and may change in the future. Members may be added, so accept keyword
    #   arguments defensively if constructing this yourself.
    #
    # @!visibility private
    class StorageDriverStoreContext; end # rubocop:disable Lint/EmptyClass
  end
end
