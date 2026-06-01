# typed: true

# Sorbet RBI types for the Temporal Ruby SDK.
# This file was split from rbi/temporalio.rbi by extra/split_rbi.rb.

class Temporalio::Converters::PayloadConverter::Composite < ::Temporalio::Converters::PayloadConverter
  extend T::Sig

  sig { returns(T::Hash[String, Temporalio::Converters::PayloadConverter::Encoding]) }
  def converters; end

  sig { params(converters: Temporalio::Converters::PayloadConverter::Encoding).void }
  def initialize(*converters); end

  sig { params(value: T.nilable(Object), hint: T.nilable(Object)).returns(Temporalio::Api::Common::V1::Payload) }
  def to_payload(value, hint: T.unsafe(nil)); end

  sig { params(payload: T.nilable(Temporalio::Api::Common::V1::Payload), hint: T.nilable(Object)).returns(T.nilable(Object)) }
  def from_payload(payload, hint: T.unsafe(nil)); end

  class ConverterNotFound < ::Temporalio::Error; end
  class EncodingNotSet < ::Temporalio::Error; end
end
