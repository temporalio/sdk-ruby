# typed: true

class Temporalio::WorkerDeploymentVersion < ::Data
  sig { params(deployment_name: String, build_id: String).void }
  def initialize(deployment_name:, build_id:); end

  sig { params(canonical: String).returns(Temporalio::WorkerDeploymentVersion) }
  def self.from_canonical_string(canonical); end

  sig { returns(String) }
  def deployment_name; end

  sig { returns(String) }
  def build_id; end

  sig { returns(String) }
  def to_canonical_string; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::WorkerDeploymentVersion) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end

    sig { params(args: T.untyped).returns(Temporalio::WorkerDeploymentVersion) }
    def new(*args); end
  end
end
