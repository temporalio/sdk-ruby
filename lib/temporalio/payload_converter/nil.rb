require 'temporalio/payload_converter/encoding_base'

module Temporalio
  module PayloadConverter
    class Nil < EncodingBase
      ENCODING = 'binary/null'.freeze

      def encoding
        ENCODING
      end

      def from_payload(_payload)
        nil
      end

      def to_payload(data)
        return nil unless data.nil?

        Temporalio::Api::Common::V1::Payload.new(
          metadata: { 'encoding' => ENCODING },
        )
      end
    end
  end
end
