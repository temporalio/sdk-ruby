# typed: true

class Temporalio::Converters::StorageDriverSelectContext
  extend T::Sig

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
  attr_reader :target

  sig { returns(Temporalio::Cancellation) }
  attr_reader :cancellation

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
end
