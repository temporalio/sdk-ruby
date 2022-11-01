module Temporal
  module PayloadConverter
    # @abstract Use this Interface for implementing your payload converter.
    class Base
      # Convert a Ruby value to a proto Payload.
      #
      # @param _data [any] Ruby value to be converted.
      #
      # @return [Temporal::Api::Common::V1::Payload]
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
