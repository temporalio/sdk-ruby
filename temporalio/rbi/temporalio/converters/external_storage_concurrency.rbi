# typed: true

class Temporalio::Converters::ExternalStorageConcurrency < ::Data
  DEFAULT_MAX_DRIVER_OPERATIONS = T.let(T.unsafe(nil), Integer)
  DEFAULT_MAX_OPERATIONS_PER_MESSAGE = T.let(T.unsafe(nil), Integer)

  sig { params(max_driver_operations: Integer, max_operations_per_message: Integer).void }
  def initialize(max_driver_operations: 64, max_operations_per_message: 8); end

  sig { returns(Integer) }
  def max_driver_operations; end

  sig { returns(Integer) }
  def max_operations_per_message; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Converters::ExternalStorageConcurrency) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end

    sig { params(args: T.untyped).returns(Temporalio::Converters::ExternalStorageConcurrency) }
    def new(*args); end
  end
end
