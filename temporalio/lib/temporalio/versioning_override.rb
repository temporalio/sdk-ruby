# frozen_string_literal: true

require 'temporalio/worker_deployment_version'

module Temporalio
  # Base class for version overrides that can be provided in start workflow options.
  # Used to control the versioning behavior of workflows started with this override.
  #
  # WARNING: Experimental API.
  class VersioningOverride
    # @!visibility private
    def _to_proto
      raise NotImplementedError, 'Subclasses must implement this method'
    end

    # Represents a versioning override to pin a workflow to a specific version
    class Pinned < VersioningOverride
      # The worker deployment version to pin to
      # @return [WorkerDeploymentVersion]
      attr_reader :version

      # Create a new pinned versioning override
      #
      # @param version [WorkerDeploymentVersion] The worker deployment version to pin to
      def initialize(version)
        @version = version
        super()
      end

      # TODO: Remove deprecated field setting once removed from server

      # @!visibility private
      def _to_proto
        Api::Workflow::V1::VersioningOverride.new(
          behavior: Api::Enums::V1::VersioningBehavior::VERSIONING_BEHAVIOR_PINNED,
          pinned_version: @version.to_canonical_string,
          pinned: Api::Workflow::V1::VersioningOverride::PinnedOverride.new(
            behavior: Api::Workflow::V1::VersioningOverride::PinnedOverrideBehavior::PINNED_OVERRIDE_BEHAVIOR_PINNED,
            version: @version._to_proto
          )
        )
      end
    end

    # Represents a versioning override to auto-upgrade a workflow
    class AutoUpgrade < VersioningOverride
      # @!visibility private
      def _to_proto
        Api::Workflow::V1::VersioningOverride.new(
          behavior: Api::Enums::V1::VersioningBehavior::VERSIONING_BEHAVIOR_AUTO_UPGRADE,
          auto_upgrade: true
        )
      end
    end
  end
end
