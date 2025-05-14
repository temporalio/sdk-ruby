# frozen_string_literal: true

require 'temporalio/worker_deployment_version'

module Temporalio
  # Base class for version overrides that can be provided in start workflow options.
  # Used to control the versioning behavior of workflows started with this override.
  #
  # Use factory methods {.auto_upgrade} or {.pinned} to create instances.
  #
  # WARNING: Experimental API.
  class VersioningOverride
    # Creates an auto-upgrade versioning override
    # The workflow will auto-upgrade to the current deployment version on the next workflow task.
    #
    # @return [AutoUpgradeVersioningOverride] An auto-upgrade versioning override
    def self.auto_upgrade
      AutoUpgradeVersioningOverride.new
    end

    # Creates a pinned versioning override
    # The workflow will be pinned to a specific deployment version.
    #
    # @param version [WorkerDeploymentVersion] The worker deployment version to pin the workflow to
    # @return [PinnedVersioningOverride] A pinned versioning override
    def self.pinned(version)
      PinnedVersioningOverride.new(version)
    end

    # @!visibility private
    def _to_proto
      raise NotImplementedError, 'Subclasses must implement this method'
    end
  end

  # Represents a versioning override to pin a workflow to a specific version
  class PinnedVersioningOverride < VersioningOverride
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
      Temporalio::Api::Workflow::V1::VersioningOverride.new(
        behavior: Temporalio::Api::Enums::V1::VersioningBehavior::VERSIONING_BEHAVIOR_PINNED,
        pinned_version: @version.to_canonical_string,
        pinned: Temporalio::Api::Workflow::V1::VersioningOverride::PinnedOverride.new(
          version: @version._to_proto
        )
      )
    end
  end

  # Represents a versioning override to auto-upgrade a workflow
  class AutoUpgradeVersioningOverride < VersioningOverride
    # @!visibility private
    def _to_proto
      Temporalio::Api::Workflow::V1::VersioningOverride.new(
        behavior: Temporalio::Api::Enums::V1::VersioningBehavior::VERSIONING_BEHAVIOR_AUTO_UPGRADE,
        auto_upgrade: true
      )
    end
  end
end
