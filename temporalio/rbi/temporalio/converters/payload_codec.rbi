# typed: true

# Sorbet RBI types for the Temporal Ruby SDK.
# This file was split from rbi/temporalio.rbi by extra/split_rbi.rb.

class Temporalio::Converters::PayloadCodec
  extend T::Sig

  sig { params(payloads: T::Enumerable[Temporalio::Api::Common::V1::Payload]).returns(T::Array[Temporalio::Api::Common::V1::Payload]) }
  def encode(payloads); end

  sig { params(payloads: T::Enumerable[Temporalio::Api::Common::V1::Payload]).returns(T::Array[Temporalio::Api::Common::V1::Payload]) }
  def decode(payloads); end
end
