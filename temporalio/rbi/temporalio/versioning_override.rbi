# typed: true

# Sorbet RBI types for the Temporal Ruby SDK.
# This file was split from rbi/temporalio.rbi by extra/split_rbi.rb.

class Temporalio::VersioningOverride; end

class Temporalio::VersioningOverride::Pinned < ::Temporalio::VersioningOverride
  sig { params(version: Temporalio::WorkerDeploymentVersion).void }
  def initialize(version); end

  sig { returns(Temporalio::WorkerDeploymentVersion) }
  attr_reader :version
end

class Temporalio::VersioningOverride::AutoUpgrade < ::Temporalio::VersioningOverride; end
