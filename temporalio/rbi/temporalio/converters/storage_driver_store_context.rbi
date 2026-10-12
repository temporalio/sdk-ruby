# typed: true

class Temporalio::Converters::StorageDriverStoreContext < ::Data
  sig do
    params(
      target: T.nilable(
        T.any(
          Temporalio::Converters::StorageDriverWorkflowInfo,
          Temporalio::Converters::StorageDriverActivityInfo
        )
      ),
      cancellation: Temporalio::Cancellation,
      limiter: Temporalio::Converters::StorageDriverLimiter
    ).void
  end
  def initialize(target:, cancellation:, limiter:); end

  sig do
    returns(
      T.nilable(
        T.any(
          Temporalio::Converters::StorageDriverWorkflowInfo,
          Temporalio::Converters::StorageDriverActivityInfo
        )
      )
    )
  end
  def target; end

  sig { returns(Temporalio::Cancellation) }
  def cancellation; end

  sig { returns(Temporalio::Converters::StorageDriverLimiter) }
  def limiter; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Converters::StorageDriverStoreContext) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end

    sig { params(args: T.untyped).returns(Temporalio::Converters::StorageDriverStoreContext) }
    def new(*args); end
  end
end
