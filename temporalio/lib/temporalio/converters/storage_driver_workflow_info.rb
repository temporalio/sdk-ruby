# frozen_string_literal: true

module Temporalio
  module Converters
    StorageDriverWorkflowInfo = Data.define(
      :namespace,
      :id,
      :run_id,
      :type
    )

    # Identity of the workflow a payload is being stored on behalf of. Also used for workflow activities, which
    # store against their owning workflow rather than themselves.
    #
    # @note WARNING: This API is experimental and may change in the future.
    #
    # @!visibility private
    class StorageDriverWorkflowInfo
      # Create workflow target information.
      #
      # @param namespace [String] Workflow namespace.
      # @param id [String, nil] Workflow ID, if known.
      # @param run_id [String, nil] Run ID, if known. Unset when the run is not yet determined, such as
      #   when starting a child workflow or continuing as new.
      # @param type [String, nil] Workflow type name, if known.
      def initialize(namespace:, id: nil, run_id: nil, type: nil)
        super
      end
    end
  end
end
