# typed: true

class Temporalio::Converters::StorageDriverRetrieveContext
  extend T::Sig

  sig { returns(Temporalio::Cancellation) }
  attr_reader :cancellation

  sig { params(cancellation: Temporalio::Cancellation).void }
  def initialize(cancellation:); end
end
