module Temporal
  module FailureConverter
    class Base
      def to_failure(_error, _payload_converter)
        raise NoMethodError, 'must implement #to_failure'
      end

      def from_failure(_failure, _payload_converter)
        raise NoMethodError, 'must implement #from_failure'
      end
    end
  end
end
