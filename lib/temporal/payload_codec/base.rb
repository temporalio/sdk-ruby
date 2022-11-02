module Temporal
  module PayloadCodec
    # @abstract Use this Interface for implementing your payload codecs.
    #
    # Codec for encoding/decoding to/from bytes. Commonly used for compression or encryption.
    class Base
      # Encode the given payloads.
      #
      # @param _payloads [Array<Temporal::Api::Common::V1::Payload>] Payloads to encode.
      #   This value should not be mutated.
      #
      # @return [Array<Temporal::Api::Common::V1::Payload>] Encoded payloads. Note, this does not
      #   have to be the same number as payloads given, but must be at least one and cannot be more
      #   than was given.
      def encode(_payloads)
        raise NoMethodError, 'must implement #encode'
      end

      # Decode the given payloads.
      #
      # @param _payloads [Array<Temporal::Api::Common::V1::Payload>] Payloads to decode. This value
      #   should not be mutated.
      #
      # @return [Array<Temporal::Api::Common::V1::Payload>] Decoded payloads. Note, this does not
      #   have to be the same number as payloads given, but must be at least one and cannot be more
      #   than was given.
      def decode(_payloads)
        raise NoMethodError, 'must implement #decode'
      end
    end
  end
end
