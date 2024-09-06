# frozen_string_literal: true

require 'temporalio/api'
require 'temporalio/converters/payload_converter/encoding'

module Temporalio
  module Converters
    class PayloadConverter
      # Encoding for +nil+ values for +binary/null+ encoding.
      class BinaryNull < Encoding
        ENCODING = 'binary/null'

        # (see Encoding.encoding)
        def encoding
          ENCODING
        end

        # (see Encoding.to_payload)
        def to_payload(value)
          return nil unless value.nil?

          Api::Common::V1::Payload.new(
            metadata: { 'encoding' => ENCODING }
          )
        end

        # (see Encoding.from_payload)
        def from_payload(payload) # rubocop:disable Lint/UnusedMethodArgument
          nil
        end
      end
    end
  end
end
