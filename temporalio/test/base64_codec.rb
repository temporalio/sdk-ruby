# frozen_string_literal: true

require 'temporalio/api'
require 'temporalio/converters/payload_codec'

class Base64Codec < Temporalio::Converters::PayloadCodec
  def encode(payloads)
    payloads.map do |p|
      Temporalio::Api::Common::V1::Payload.new(
        metadata: { 'encoding' => 'test/base64' },
        data: Base64.strict_encode64(p.to_proto)
      )
    end
  end

  def decode(payloads)
    payloads.map do |p|
      Temporalio::Api::Common::V1::Payload.decode(
        Base64.strict_decode64(p.data)
      )
    end
  end
end
