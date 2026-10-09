# typed: true

class Temporalio::Converters::StorageDriverRetrieveContext < ::Data
  sig { params(cancellation: Temporalio::Cancellation).void }
  def initialize(cancellation:); end

  sig { returns(Temporalio::Cancellation) }
  def cancellation; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Converters::StorageDriverRetrieveContext) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end

    sig { params(args: T.untyped).returns(Temporalio::Converters::StorageDriverRetrieveContext) }
    def new(*args); end
  end
end
