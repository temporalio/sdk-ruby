module Temporal
  module PayloadConverter
    class Base
      def to_payload(_data)
        raise NoMethodError, 'must implement #to_payload'
      end

      def from_payload(_payload)
        raise NoMethodError, 'must implement #from_payload'
      end
    end
  end
end
