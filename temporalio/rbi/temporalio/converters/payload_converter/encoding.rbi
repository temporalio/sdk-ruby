# typed: true

# Sorbet RBI types for the Temporal Ruby SDK.
# This file was split from rbi/temporalio.rbi by extra/split_rbi.rb.

class Temporalio::Converters::PayloadConverter::Encoding
  extend T::Sig

  sig { returns(String) }
  def encoding; end

  sig { params(value: T.nilable(Object), hint: T.nilable(Object)).returns(T.nilable(Temporalio::Api::Common::V1::Payload)) }
  def to_payload(value, hint: T.unsafe(nil)); end

  sig { params(payload: T.nilable(Temporalio::Api::Common::V1::Payload), hint: T.nilable(Object)).returns(T.nilable(Object)) }
  def from_payload(payload, hint: T.unsafe(nil)); end
end
