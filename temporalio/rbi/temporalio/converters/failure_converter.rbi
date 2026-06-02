# typed: true

# Sorbet RBI types for the Temporal Ruby SDK.
# This file was split from rbi/temporalio.rbi by extra/split_rbi.rb.

class Temporalio::Converters::FailureConverter
  extend T::Sig

  sig { returns(Temporalio::Converters::FailureConverter) }
  def self.default; end

  sig { params(encode_common_attributes: T::Boolean).void }
  def initialize(encode_common_attributes: T.unsafe(nil)); end

  sig { returns(T::Boolean) }
  attr_reader :encode_common_attributes

  sig { params(error: Exception, converter: T.any(Temporalio::Converters::DataConverter, Temporalio::Converters::PayloadConverter)).returns(Temporalio::Api::Failure::V1::Failure) }
  def to_failure(error, converter); end

  sig { params(failure: Temporalio::Api::Failure::V1::Failure, converter: T.any(Temporalio::Converters::DataConverter, Temporalio::Converters::PayloadConverter)).returns(Exception) }
  def from_failure(failure, converter); end
end
