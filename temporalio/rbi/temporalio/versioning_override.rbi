# typed: true

class Temporalio::VersioningOverride; end

class Temporalio::VersioningOverride::Pinned < ::Temporalio::VersioningOverride
  sig { params(version: Temporalio::WorkerDeploymentVersion).void }
  def initialize(version); end

  sig { returns(Temporalio::WorkerDeploymentVersion) }
  attr_reader :version
end

class Temporalio::VersioningOverride::AutoUpgrade < ::Temporalio::VersioningOverride; end
