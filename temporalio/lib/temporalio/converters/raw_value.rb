# frozen_string_literal: true

module Temporalio
  module Converters
    # Raw value wrapper that has the raw payload. When raw args are configured at implementation time, the inbound
    # arguments will be instances of this class. When instances of this class are sent outbound or returned from
    # inbound calls, the raw payload will be serialized instead of applying traditional conversion.
    class RawValue
      # @return [Api::Common::V1::Payload] Payload.
      attr_reader :payload

      # Create a raw value.
      #
      # @param payload [Api::Common::V1::Payload] Payload.
      def initialize(payload)
        @payload = payload
      end
    end
  end
end
