# frozen_string_literal: true

module Temporalio
  module Converters
    # Base class for encoding and decoding payloads. Commonly used for encryption.
    class PayloadCodec
      # Encode the given payloads into a new set of payloads.
      #
      # @param payloads [Enumerable<Api::Common::V1::Payload>] Payloads to encode. This value should not be mutated.
      # @return [Array<Api::Common::V1::Payload>] Encoded payloads. Note, this does not have to be the same number as
      #   payloads given, but it must be at least one and cannot be more than was given.
      def encode(payloads)
        raise NotImplementedError
      end

      # Decode the given payloads into a new set of payloads.
      #
      # @param payloads [Enumerable<Api::Common::V1::Payload>] Payloads to decode. This value should not be mutated.
      # @return [Array<Api::Common::V1::Payload>] Decoded payloads. Note, this does not have to be the same number as
      #   payloads given, but it must be at least one and cannot be more than was given.
      def decode(payloads)
        raise NotImplementedError
      end
    end
  end
end
