# typed: true

class Temporalio::Converters::FailureConverter
  extend T::Sig

  sig { returns(Temporalio::Converters::FailureConverter) }
  def self.default; end

  sig do
    params(
      encode_common_attributes: T::Boolean,
      process_common_attributes: T.nilable(T.proc.params(arg0: T::Hash[Symbol, T.nilable(String)]).returns(Object))
    ).void
  end
  def initialize(encode_common_attributes: T.unsafe(nil), process_common_attributes: T.unsafe(nil)); end

  sig { returns(T::Boolean) }
  attr_reader :encode_common_attributes

  sig { params(error: Exception, converter: T.any(Temporalio::Converters::DataConverter, Temporalio::Converters::PayloadConverter)).returns(Temporalio::Api::Failure::V1::Failure) }
  def to_failure(error, converter); end

  sig { params(failure: Temporalio::Api::Failure::V1::Failure, converter: T.any(Temporalio::Converters::DataConverter, Temporalio::Converters::PayloadConverter)).returns(Exception) }
  def from_failure(failure, converter); end
end
