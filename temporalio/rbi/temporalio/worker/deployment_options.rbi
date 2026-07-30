# typed: true

class Temporalio::Worker::DeploymentOptions < ::Data
  extend T::Sig

  sig { returns(Temporalio::WorkerDeploymentVersion) }
  def version; end

  sig { returns(T::Boolean) }
  def use_worker_versioning; end

  sig { returns(Integer) }
  def default_versioning_behavior; end

  sig do
    params(
      version: Temporalio::WorkerDeploymentVersion,
      use_worker_versioning: T::Boolean,
      default_versioning_behavior: Integer
    ).void
  end
  def initialize(version:, use_worker_versioning: T.unsafe(nil), default_versioning_behavior: T.unsafe(nil)); end
end
