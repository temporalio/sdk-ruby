# typed: true

class Temporalio::Converters::PayloadCodec
  extend T::Sig

  sig { params(payloads: T::Enumerable[Temporalio::Api::Common::V1::Payload]).returns(T::Array[Temporalio::Api::Common::V1::Payload]) }
  def encode(payloads); end

  sig { params(payloads: T::Enumerable[Temporalio::Api::Common::V1::Payload]).returns(T::Array[Temporalio::Api::Common::V1::Payload]) }
  def decode(payloads); end
end
