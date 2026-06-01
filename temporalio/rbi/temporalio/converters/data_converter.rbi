# typed: true

# Sorbet RBI types for the Temporal Ruby SDK.
# This file was split from rbi/temporalio.rbi by extra/split_rbi.rb.

class Temporalio::Converters::DataConverter
  extend T::Sig

  sig { returns(Temporalio::Converters::PayloadConverter) }
  def payload_converter; end

  sig { returns(Temporalio::Converters::FailureConverter) }
  def failure_converter; end

  sig { returns(T.nilable(Temporalio::Converters::PayloadCodec)) }
  def payload_codec; end

  sig { returns(Temporalio::Converters::DataConverter) }
  def self.default; end

  sig do
    params(
      payload_converter: Temporalio::Converters::PayloadConverter,
      failure_converter: Temporalio::Converters::FailureConverter,
      payload_codec: T.nilable(Temporalio::Converters::PayloadCodec)
    ).void
  end
  def initialize(payload_converter: T.unsafe(nil), failure_converter: T.unsafe(nil), payload_codec: T.unsafe(nil)); end

  sig { params(value: T.nilable(Object), hint: T.nilable(Object)).returns(Temporalio::Api::Common::V1::Payload) }
  def to_payload(value, hint: T.unsafe(nil)); end

  sig { params(values: T::Array[T.nilable(Object)], hints: T.nilable(T::Array[Object])).returns(Temporalio::Api::Common::V1::Payloads) }
  def to_payloads(values, hints: T.unsafe(nil)); end

  sig { params(payload: Temporalio::Api::Common::V1::Payload, hint: T.nilable(Object)).returns(T.nilable(Object)) }
  def from_payload(payload, hint: T.unsafe(nil)); end

  sig { params(payloads: T.nilable(Temporalio::Api::Common::V1::Payloads), hints: T.nilable(T::Array[Object])).returns(T::Array[T.nilable(Object)]) }
  def from_payloads(payloads, hints: T.unsafe(nil)); end

  sig { params(error: Exception).returns(Temporalio::Api::Failure::V1::Failure) }
  def to_failure(error); end

  sig { params(failure: Temporalio::Api::Failure::V1::Failure).returns(Exception) }
  def from_failure(failure); end
end
