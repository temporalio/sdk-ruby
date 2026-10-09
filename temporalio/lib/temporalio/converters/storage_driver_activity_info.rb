# frozen_string_literal: true

module Temporalio
  module Converters
    StorageDriverActivityInfo = Data.define(
      :namespace,
      :id,
      :run_id,
      :type
    )

    # Identity of a standalone activity a payload is being stored on behalf of.
    #
    # @note WARNING: This API is experimental and may change in the future.
    #
    # @!attribute [r] namespace
    #   @return [String] Activity namespace.
    # @!attribute [r] id
    #   @return [String, nil] Activity ID, if known.
    # @!attribute [r] run_id
    #   @return [String, nil] Run ID, if known.
    # @!attribute [r] type
    #   @return [String, nil] Activity type name, if known.
    #
    # @!visibility private
    class StorageDriverActivityInfo
      # Create activity target information.
      #
      # @param namespace [String] Activity namespace.
      # @param id [String, nil] Activity ID.
      # @param run_id [String, nil] Run ID.
      # @param type [String, nil] Activity type name.
      def initialize(namespace:, id: nil, run_id: nil, type: nil)
        super
      end
    end
  end
end
