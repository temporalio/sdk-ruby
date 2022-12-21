module Temporalio
  module FailureConverter
    # @abstract Use this Interface for implementing your failure converter.
    class Base
      # Convert an Error object to a proto Failure.
      #
      # @param _error [Exception] An Error to be converter.
      # @param _payload_converter [Temporalio::PayloadConverter::Base] A payload converter.
      #
      # @return [Temporalio::Api::Failure::V1::Failure]
      def to_failure(_error, _payload_converter)
        raise NoMethodError, 'must implement #to_failure'
      end

      # Convert an proto Failure object to an Error.
      #
      # @param _failure [Temporalio::Api::Failure::V1::Failure] A proto Failure to be converted.
      # @param _payload_converter [Temporalio::PayloadConverter::Base] A payload converter.
      #
      # @return [Exception]
      def from_failure(_failure, _payload_converter)
        raise NoMethodError, 'must implement #from_failure'
      end
    end
  end
end
