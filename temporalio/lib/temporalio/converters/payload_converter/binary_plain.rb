# frozen_string_literal: true

require 'temporalio/api'
require 'temporalio/converters/payload_converter/encoding'

module Temporalio
  module Converters
    class PayloadConverter
      # Encoding for +ASCII_8BIT+ string values for +binary/plain+ encoding.
      class BinaryPlain < Encoding
        ENCODING = 'binary/plain'

        # (see Encoding.encoding)
        def encoding
          ENCODING
        end

        # (see Encoding.to_payload)
        def to_payload(value, hint: nil) # rubocop:disable Lint/UnusedMethodArgument
          return nil unless value.is_a?(String) && value.encoding == ::Encoding::ASCII_8BIT

          Temporalio::Api::Common::V1::Payload.new(
            metadata: { 'encoding' => ENCODING },
            data: value
          )
        end

        # (see Encoding.from_payload)
        def from_payload(payload, hint: nil) # rubocop:disable Lint/UnusedMethodArgument
          payload.data
        end
      end
    end
  end
end
