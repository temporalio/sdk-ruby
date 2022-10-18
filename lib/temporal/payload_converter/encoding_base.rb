require 'temporal/api/common/v1/message_pb'

module Temporal
  module PayloadConverter
    class EncodingBase
      def encoding
        raise NoMethodError, 'must implement #encoding'
      end

      def to_payload(_data)
        raise NoMethodError, 'must implement #to_payload'
      end

      def from_payload(_payload)
        raise NoMethodError, 'must implement #from_payload'
      end
    end
  end
end
