# frozen_string_literal: true

module Temporalio
  WorkerDeploymentVersion = Data.define(
    :deployment_name,
    :build_id
  )

  # Represents the version of a specific worker deployment.
  #
  # WARNING: Experimental API.
  class WorkerDeploymentVersion
    # Parse a version from a canonical string, which must be in the format
    # `<deployment_name>.<build_id>`. Deployment name must not have a `.` in it.
    def self.from_canonical_string(canonical)
      parts = canonical.split('.', 2)
      if parts.length != 2
        raise ArgumentError,
              "Cannot parse version string: #{canonical}, must be in format <deployment_name>.<build_id>"
      end
      new(parts[0], parts[1])
    end

    # @!visibility private
    def self._from_bridge(bridge)
      new(deployment_name: bridge.deployment_name, build_id: bridge.build_id)
    end

    # Create WorkerDeploymentVersion.
    #
    # @param deployment_name [String] The name of the deployment.
    # @param build_id [String] The build identifier specific to this worker build.
    def initialize(deployment_name:, build_id:) # rubocop:disable Lint/UselessMethodDefinition
      super
    end

    # Returns the canonical string representation of the version.
    def to_canonical_string
      "#{deployment_name}.#{build_id}"
    end

    # @!visibility private
    def _to_bridge_options
      Internal::Bridge::Worker::WorkerDeploymentVersion.new(
        deployment_name: deployment_name,
        build_id: build_id
      )
    end
  end
end
