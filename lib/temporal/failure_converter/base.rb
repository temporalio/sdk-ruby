module Temporal
  module FailureConverter
    class Base
      def to_failure(_error)
        raise NoMethodError, 'must implement #to_failure'
      end

      def from_failure(_failure)
        raise NoMethodError, 'must implement #from_failure'
      end
    end
  end
end
