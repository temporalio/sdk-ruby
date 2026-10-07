# typed: true

class Temporalio::VersioningOverride; end

class Temporalio::VersioningOverride::Pinned < ::Temporalio::VersioningOverride
  sig { params(version: Temporalio::WorkerDeploymentVersion).void }
  def initialize(version); end

  sig { returns(Temporalio::WorkerDeploymentVersion) }
  attr_reader :version
end

class Temporalio::VersioningOverride::AutoUpgrade < ::Temporalio::VersioningOverride; end

class Temporalio::VersioningOverride::OneTime < ::Temporalio::VersioningOverride
  sig { params(target_version: Temporalio::WorkerDeploymentVersion).void }
  def initialize(target_version); end

  sig { returns(Temporalio::WorkerDeploymentVersion) }
  attr_reader :target_version
end
