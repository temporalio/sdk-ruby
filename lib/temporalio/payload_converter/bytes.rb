require 'temporalio/payload_converter/encoding_base'

module Temporalio
  module PayloadConverter
    # A payload converter for encoding/decoding byte strings.
    class Bytes < EncodingBase
      ENCODING = 'binary/plain'.freeze

      def encoding
        ENCODING
      end

      def from_payload(payload)
        payload.data
      end

      def to_payload(data)
        return nil unless data.is_a?(String) && data.encoding == Encoding::ASCII_8BIT

        Temporalio::Api::Common::V1::Payload.new(
          metadata: { 'encoding' => ENCODING },
          data: data,
        )
      end
    end
  end
end
