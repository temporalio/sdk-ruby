# typed: true

class Temporalio::Converters::StorageDriverSelectContext < ::Data
  sig do
    params(
      target: T.nilable(
        T.any(
          Temporalio::Converters::StorageDriverWorkflowInfo,
          Temporalio::Converters::StorageDriverActivityInfo
        )
      ),
      cancellation: Temporalio::Cancellation
    ).void
  end
  def initialize(target:, cancellation:); end

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

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Converters::StorageDriverSelectContext) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end

    sig { params(args: T.untyped).returns(Temporalio::Converters::StorageDriverSelectContext) }
    def new(*args); end
  end
end
