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
      # @return [PayloadConverter::Composite] Default payload converter.
      def self.default
        @default ||= new_with_defaults
      end

      # Create a new payload converter with the default set of encoding converters.
      #
      # @param json_parse_options [Hash] Options for {::JSON.parse}.
      # @param json_generate_options [Hash] Options for {::JSON.generate}.
      # @return [PayloadConverter::Composite] Created payload converter.
      def self.new_with_defaults(json_parse_options: { create_additions: true }, json_generate_options: {})
        PayloadConverter::Composite.new(
          PayloadConverter::BinaryNull.new,
          PayloadConverter::BinaryPlain.new,
          PayloadConverter::JSONProtobuf.new,
          PayloadConverter::BinaryProtobuf.new,
          PayloadConverter::JSONPlain.new(parse_options: json_parse_options, generate_options: json_generate_options)
        )
      end

      # Convert a Ruby value to a payload.
      #
      # @param value [Object] Ruby value.
      # @param hint [Object, nil] Hint, if any, to assist conversion.
      # @return [Api::Common::V1::Payload] Converted payload.
      def to_payload(value, hint: nil)
        raise NotImplementedError
      end

      # Convert multiple Ruby values to a payload set.
      #
      # @param values [Object] Ruby values, converted to array via {::Array}.
      # @param hints [Array<Object>, nil] Hints, if any, to assist conversion. Note, when using the default converter
      #   that converts a payload at a time, hints for each value are taken from the array at that value's index. So if
      #   there are fewer hints than values, some values will not have a hint. Similarly if there are more hints than
      #   values, the trailing hints are not used.
      # @return [Api::Common::V1::Payloads] Converted payload set.
      def to_payloads(values, hints: nil)
        Api::Common::V1::Payloads.new(
          payloads: Array(values).zip(Array(hints)).map { |value, hint| to_payload(value, hint:) }
        )
      end

      # Convert a payload to a Ruby value.
      #
      # @param payload [Api::Common::V1::Payload] Payload.
      # @param hint [Object, nil] Hint, if any, to assist conversion.
      # @return [Object] Converted Ruby value.
      def from_payload(payload, hint: nil)
        raise NotImplementedError
      end

      # Convert a payload set to Ruby values.
      #
      # @param payloads [Api::Common::V1::Payloads, nil] Payload set.
      # @param hints [Array<Object>, nil] Hints, if any, to assist conversion. Note, when using the default converter
      #   that converts a value at a time, hints for each payload are taken from the array at that payload's index. So
      #   if there are fewer hints than payloads, some payloads will not have a hint. Similarly if there are more hints
      #   than payloads, the trailing hints are not used.
      # @return [Array<Object>] Converted Ruby values.
      def from_payloads(payloads, hints: nil)
        return [] unless payloads

        payloads.payloads.zip(Array(hints)).map { |payload, hint| from_payload(payload, hint:) }
      end
    end
  end
end
