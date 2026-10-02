# frozen_string_literal: true

module Temporalio
  module Converters
    # Identity of the workflow a payload is being stored on behalf of. Also used for workflow activities, which store
    # against their owning workflow rather than themselves.
    #
    # @note WARNING: This API is experimental and may change in the future.
    #
    # @!visibility private
    class StorageDriverWorkflowInfo
      # @return [String] Workflow namespace.
      attr_reader :namespace

      # @return [String, nil] Workflow ID, if known.
      attr_reader :id

      # @return [String, nil] Run ID, if known. Unset when the run is not yet determined, such as when starting a child
      #   workflow or continuing as new.
      attr_reader :run_id

      # @return [String, nil] Workflow type name, if known.
      attr_reader :type

      # Create workflow target information.
      #
      # @param namespace [String] Workflow namespace.
      # @param id [String, nil] Workflow ID.
      # @param run_id [String, nil] Run ID.
      # @param type [String, nil] Workflow type name.
      def initialize(namespace:, id: nil, run_id: nil, type: nil)
        @namespace = namespace
        @id = id
        @run_id = run_id
        @type = type
      end
    end
  end
end
