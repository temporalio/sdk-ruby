# frozen_string_literal: true

module Temporalio
  module Converters
    # Identity of a standalone activity a payload is being stored on behalf of.
    #
    # @note WARNING: This API is experimental and may change in the future.
    #
    # @!visibility private
    class StorageDriverActivityInfo
      # @return [String] Activity namespace.
      attr_reader :namespace

      # @return [String, nil] Activity ID, if known.
      attr_reader :id

      # @return [String, nil] Run ID, if known.
      attr_reader :run_id

      # @return [String, nil] Activity type name, if known.
      attr_reader :type

      # Create activity target information.
      #
      # @param namespace [String] Activity namespace.
      # @param id [String, nil] Activity ID.
      # @param run_id [String, nil] Run ID.
      # @param type [String, nil] Activity type name.
      def initialize(namespace:, id: nil, run_id: nil, type: nil)
        @namespace = namespace
        @id = id
        @run_id = run_id
        @type = type
      end
    end
  end
end
