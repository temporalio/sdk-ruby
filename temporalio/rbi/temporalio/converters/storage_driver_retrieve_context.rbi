# typed: true

class Temporalio::Converters::StorageDriverRetrieveContext < ::Data
  sig { params(cancellation: Temporalio::Cancellation, limiter: Temporalio::Converters::StorageDriverLimiter).void }
  def initialize(cancellation:, limiter:); end

  sig { returns(Temporalio::Cancellation) }
  def cancellation; end

  sig { returns(Temporalio::Converters::StorageDriverLimiter) }
  def limiter; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Converters::StorageDriverRetrieveContext) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end

    sig { params(args: T.untyped).returns(Temporalio::Converters::StorageDriverRetrieveContext) }
    def new(*args); end
  end
end
