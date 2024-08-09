# frozen_string_literal: true

require 'temporalio/converters/payload_converter/binary_null'
require 'temporalio/converters/payload_converter/binary_plain'
require 'temporalio/converters/payload_converter/binary_protobuf'
require 'temporalio/converters/payload_converter/composite'
require 'temporalio/converters/payload_converter/json_plain'
require 'temporalio/converters/payload_converter/json_protobuf'

module Temporalio
  module Converters
    # Base class for converting Ruby values to/from Temporal payloads.
    class PayloadConverter
      # @return [FailureConverter] Default payload converter.
      def self.default
        @default ||= new_with_defaults
      end

      # Create a new payload converter with the default set of encoding converters.
      #
      # @param json_parse_options [Hash] Options for {::JSON.parse}.
      # @param json_generate_options [Hash] Options for {::JSON.generate}.
      def self.new_with_defaults(json_parse_options: { create_additions: true }, json_generate_options: {})
        Ractor.make_shareable(
          PayloadConverter::Composite.new(
            PayloadConverter::BinaryNull.new,
            PayloadConverter::BinaryPlain.new,
            PayloadConverter::JSONProtobuf.new,
            PayloadConverter::BinaryProtobuf.new,
            PayloadConverter::JSONPlain.new(parse_options: json_parse_options, generate_options: json_generate_options)
          )
        )
      end

      # Convert a Ruby value to a payload.
      #
      # @param value [Object] Ruby value.
      # @return [Api::Common::V1::Payload] Converted payload.
      def to_payload(value)
        raise NotImplementedError
      end

      # Convert a payload to a Ruby value.
      #
      # @param payload [Api::Common::V1::Payload] Payload.
      # @return [Object] Converted Ruby value.
      def from_payload(payload)
        raise NotImplementedError
      end
    end
  end
end
