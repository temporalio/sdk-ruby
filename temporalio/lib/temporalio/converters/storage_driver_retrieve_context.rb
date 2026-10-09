# frozen_string_literal: true

require 'temporalio/cancellation'

module Temporalio
  module Converters
    StorageDriverRetrieveContext = Data.define(:cancellation)

    # Context given to {StorageDriver#retrieve}.
    #
    # This deliberately carries no execution target. A payload must be retrievable from its {StorageDriverClaim}
    # alone, since the same payload can be read from a different execution than the one that stored it.
    #
    # @note WARNING: This API is experimental and may change in the future. Members may be added, so accept keyword
    #   arguments defensively if constructing this yourself.
    #
    # @!attribute [r] cancellation
    #   @return [Cancellation] Cancelled when the SDK abandons this retrieve operation.
    #
    # @!visibility private
    class StorageDriverRetrieveContext; end # rubocop:disable Lint/EmptyClass
  end
end
