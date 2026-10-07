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
    # @!visibility private
    class StorageDriverSelectContext; end # rubocop:disable Lint/EmptyClass
  end
end
