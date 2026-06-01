# typed: true

# Sorbet RBI types for the Temporal Ruby SDK.
# This file was split from rbi/temporalio.rbi by extra/split_rbi.rb.

class Temporalio::Converters::PayloadConverter
  extend T::Sig

  sig { returns(Temporalio::Converters::PayloadConverter::Composite) }
  def self.default; end

  sig do
    params(
      json_parse_options: T::Hash[Symbol, Object],
      json_generate_options: T::Hash[Symbol, Object]
    ).returns(Temporalio::Converters::PayloadConverter::Composite)
  end
  def self.new_with_defaults(json_parse_options: T.unsafe(nil), json_generate_options: T.unsafe(nil)); end

  sig { params(value: T.nilable(Object), hint: T.nilable(Object)).returns(Temporalio::Api::Common::V1::Payload) }
  def to_payload(value, hint: T.unsafe(nil)); end

  sig { params(values: T::Array[T.nilable(Object)], hints: T.nilable(T::Array[Object])).returns(Temporalio::Api::Common::V1::Payloads) }
  def to_payloads(values, hints: T.unsafe(nil)); end

  sig { params(payload: Temporalio::Api::Common::V1::Payload, hint: T.nilable(Object)).returns(T.nilable(Object)) }
  def from_payload(payload, hint: T.unsafe(nil)); end

  sig { params(payloads: T.nilable(Temporalio::Api::Common::V1::Payloads), hints: T.nilable(T::Array[Object])).returns(T::Array[T.nilable(Object)]) }
  def from_payloads(payloads, hints: T.unsafe(nil)); end
end
