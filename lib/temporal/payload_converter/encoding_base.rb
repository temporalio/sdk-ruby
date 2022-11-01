require 'temporal/api/common/v1/message_pb'

module Temporal
  module PayloadConverter
    # @abstract Use this Interface for implementing an encoding payload converter.
    #   This is used as a converter for the {Temporal::PayloadConverter::Composite}.
    class EncodingBase
      # A mime-type for the converter's encoding.
      #
      # @return [String]
      def encoding
        raise NoMethodError, 'must implement #encoding'
      end

      # Convert a Ruby value to a proto Payload.
      #
      # @param _data [any] Ruby value to be converted.
      #
      # @return [Temporal::Api::Common::V1::Payload, nil] Return `nil` if the received value is not
      #   supported by this converter.
      def to_payload(_data)
        raise NoMethodError, 'must implement #to_payload'
      end

      # Convert a proto Payload to a Ruby value.
      #
      # @param _payload [Temporal::Api::Common::V1::Payload] Proto Payload to be converted.
      #
      # @return [any]
      def from_payload(_payload)
        raise NoMethodError, 'must implement #from_payload'
      end
    end
  end
end
