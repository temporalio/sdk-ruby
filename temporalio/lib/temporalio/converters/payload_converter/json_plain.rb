# frozen_string_literal: true

require 'json'
require 'temporalio/api'
require 'temporalio/converters/payload_converter/encoding'

module Temporalio
  module Converters
    class PayloadConverter
      # Encoding for all values for +json/plain+ encoding.
      class JSONPlain < Encoding
        ENCODING = 'json/plain'

        # Create JSONPlain converter.
        #
        # @param parse_options [Hash] Options for {::JSON.parse}.
        # @param generate_options [Hash] Options for {::JSON.generate}.
        def initialize(parse_options: { create_additions: true }, generate_options: {})
          super()
          @parse_options = parse_options
          @generate_options = generate_options
        end

        # (see Encoding.encoding)
        def encoding
          ENCODING
        end

        # (see Encoding.to_payload)
        def to_payload(value)
          Api::Common::V1::Payload.new(
            metadata: { 'encoding' => ENCODING },
            data: JSON.generate(value, @generate_options).b
          )
        end

        # (see Encoding.from_payload)
        def from_payload(payload)
          JSON.parse(payload.data, @parse_options)
        end
      end
    end
  end
end
