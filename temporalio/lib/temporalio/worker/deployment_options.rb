# frozen_string_literal: true

require 'temporalio/common_enums'
require 'temporalio/worker_deployment_version'

module Temporalio
  class Worker
    DeploymentOptions = Data.define(
      :version,
      :use_worker_versioning,
      :default_versioning_behavior
    )

    # Options for configuring the Worker Versioning feature.
    #
    # WARNING: Deployment-based versioning is experimental and APIs may change.
    #
    # @!attribute version
    #   @return [WorkerDeploymentVersion] The worker deployment version.
    # @!attribute use_worker_versioning
    #   @return [Boolean] Whether worker versioning is enabled.
    # @!attribute default_versioning_behavior
    #   @return [VersioningBehavior] The default versioning behavior.
    class DeploymentOptions
      def initialize(
        version:,
        use_worker_versioning: false,
        default_versioning_behavior: VersioningBehavior::UNSPECIFIED
      )
        super
      end

      # @!visibility private
      def _to_bridge_options
        Internal::Bridge::Worker::DeploymentOptions.new(
          version: Internal::Bridge::Worker::WorkerDeploymentVersion.new(
            deployment_name: version.deployment_name, build_id: version.build_id
          ),
          use_worker_versioning: use_worker_versioning,
          default_versioning_behavior: default_versioning_behavior
        )
      end
    end
  end
end
