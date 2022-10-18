module Temporal
  module PayloadCodec
    class Base
      def encode(_payloads)
        raise NoMethodError, 'must implement #encode'
      end

      def decode(_payloads)
        raise NoMethodError, 'must implement #decode'
      end
    end
  end
end
