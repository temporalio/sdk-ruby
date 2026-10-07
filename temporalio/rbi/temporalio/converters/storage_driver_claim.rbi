# typed: true

class Temporalio::Converters::StorageDriverClaim < ::Data
  sig { params(claim_data: T::Hash[String, String]).void }
  def initialize(claim_data:); end

  sig { returns(T::Hash[String, String]) }
  def claim_data; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Converters::StorageDriverClaim) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end

    sig { params(args: T.untyped).returns(Temporalio::Converters::StorageDriverClaim) }
    def new(*args); end
  end
end
