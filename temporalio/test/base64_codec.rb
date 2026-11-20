# frozen_string_literal: true

require 'temporalio/api'
require 'temporalio/converters/payload_codec'

class Base64Codec < Temporalio::Converters::PayloadCodec
  def initialize(pass_through_other_encodings: false)
    super()
    @pass_through_other_encodings = pass_through_other_encodings
  end

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
      next p if @pass_through_other_encodings && p.metadata['encoding'] != 'test/base64'

      Temporalio::Api::Common::V1::Payload.decode(
        Base64.strict_decode64(p.data)
      )
    end
  end
end
