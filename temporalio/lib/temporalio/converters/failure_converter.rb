# frozen_string_literal: true

module Temporalio
  module Converters
    # Base class for converting Ruby errors to/from Temporal failures.
    class FailureConverter
      # @return [FailureConverter] Default failure converter.
      def self.default
        @default ||= Ractor.make_shareable(FailureConverter.new)
      end

      # Create failure converter.
      #
      # @param encode_common_attributes [Boolean] If +true+, the message and stack trace of the failure will be moved
      #   into the encoded attribute section of the failure which can be encoded with a codec.
      def initialize(encode_common_attributes: false)
        @encode_common_attributes = encode_common_attributes
      end

      # Convert a Ruby error to a Temporal failure.
      #
      # @param error [Exception] Ruby error.
      # @param payload_converter [PayloadConverter] Payload converter.
      # @return [Api::Failure::V1::Failure] Converted failure.
      def to_failure(error, payload_converter)
        # TODO
        raise NotImplementedError
      end

      # Convert a Temporal failure to a Ruby error.
      #
      # @param failure [Api::Failure::V1::Failure] Failure.
      # @param payload_converter [PayloadConverter] Payload converter.
      # @return [Exception] Converted Ruby error.
      def from_failure(failure, payload_converter)
        # TODO
        raise NotImplementedError
      end
    end
  end
end
