require 'json/ext'
require 'temporal/converter/encoding_base'

module Temporal
  module Converter
    class JSON < EncodingBase
      ENCODING = 'json/plain'.freeze

      def encoding
        ENCODING
      end

      def from_payload(payload)
        ::JSON.parse(payload.data, create_additions: true)
      end

      def to_payload(data)
        Temporal::Api::Common::V1::Payload.new(
          metadata: { 'encoding' => ENCODING },
          data: ::JSON.generate(data).b,
        )
      end
    end
  end
end
