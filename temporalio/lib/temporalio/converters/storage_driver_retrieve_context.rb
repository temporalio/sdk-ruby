# frozen_string_literal: true

require 'temporalio/cancellation'

module Temporalio
  module Converters
    # Context given to {StorageDriver#retrieve}.
    #
    # This deliberately carries no target. A payload must be retrievable from its {StorageDriverClaim} alone, since the
    # same payload can be read from a different execution than the one that stored it.
    #
    # @note WARNING: This API is experimental and may change in the future. Members may be added, so accept keyword
    #   arguments defensively if constructing this yourself.
    #
    # @!visibility private
    class StorageDriverRetrieveContext
      # @return [Cancellation] Cancelled when the SDK abandons this retrieve operation.
      attr_reader :cancellation

      # Create a retrieve context.
      #
      # @param cancellation [Cancellation] Cancellation for the operation.
      def initialize(cancellation:)
        @cancellation = cancellation
      end
    end
  end
end
