# frozen_string_literal: true

require 'temporalio/worker_deployment_version'

module Temporalio
  # Base class for version overrides that can be provided when starting workflows, including child workflows.
  # Used to control the versioning behavior of workflows started with this override.
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

    # Routes workflow tasks to a target deployment version until a task completes there, then clears the override.
    # Subsequent tasks follow the workflow's normal versioning behavior.
    #
    # Requires Temporal Server 1.32.0 or later.
    # WARNING: This override is experimental.
    class OneTime < VersioningOverride
      # @return [WorkerDeploymentVersion] Target worker deployment version.
      attr_reader :target_version

      # Create a one-time versioning override.
      #
      # @param target_version [WorkerDeploymentVersion] Target worker deployment version.
      def initialize(target_version)
        @target_version = target_version
        super()
      end

      # @!visibility private
      def _to_proto
        Api::Workflow::V1::VersioningOverride.new(
          one_time: Api::Workflow::V1::VersioningOverride::OneTimeOverride.new(
            target_deployment_version: @target_version._to_proto
          )
        )
      end
    end
  end
end
