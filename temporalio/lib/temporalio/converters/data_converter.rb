# frozen_string_literal: true

require 'temporalio/api'
require 'temporalio/converters/failure_converter'
require 'temporalio/converters/payload_converter'

module Temporalio
  module Converters
    # Data converter for converting/encoding payloads to/from Ruby values.
    class DataConverter
      # @return [PayloadConverter] Payload converter.
      attr_reader :payload_converter

      # @return [FailureConverter] Failure converter.
      attr_reader :failure_converter

      # @return [PayloadCodec, nil] Optional codec for encoding/decoding payload bytes such as for encryption.
      attr_reader :payload_codec

      # @return [DataConverter] Default data converter.
      def self.default
        @default ||= DataConverter.new
      end

      # Create data converter.
      #
      # @param payload_converter [PayloadConverter] Payload converter to use.
      # @param failure_converter [FailureConverter] Failure converter to use.
      # @param payload_codec [PayloadCodec, nil] Payload codec to use.
      def initialize(
        payload_converter: PayloadConverter.default,
        failure_converter: FailureConverter.default,
        payload_codec: nil
      )
        @payload_converter = payload_converter
        @failure_converter = failure_converter
        @payload_codec = payload_codec
      end

      # Convert a Ruby value to a payload and encode it.
      #
      # @param value [Object] Ruby value.
      # @return [Api::Common::V1::Payload] Converted and encoded payload.
      def to_payload(value)
        payload = payload_converter.to_payload(value)
        payload = payload_codec.encode([payload]).first if payload_codec
        payload
      end

      # Convert multiple Ruby values to a payload set and encode it.
      #
      # @param values [Object] Ruby values, converted to array via {::Array}.
      # @return [Api::Common::V1::Payloads] Converted and encoded payload set.
      def to_payloads(values)
        payloads = payload_converter.to_payloads(values)
        payloads.payloads.replace(payload_codec.encode(payloads.payloads)) if payload_codec && !payloads.payloads.empty?
        payloads
      end

      # Decode and convert a payload to a Ruby value.
      #
      # @param payload [Api::Common::V1::Payload] Encoded payload.
      # @return [Object] Decoded and converted Ruby value.
      def from_payload(payload)
        payload = payload_codec.decode([payload]).first if payload_codec
        payload_converter.from_payload(payload)
      end

      # Decode and convert a payload set to Ruby values.
      #
      # @param payloads [Api::Common::V1::Payloads, nil] Encoded payload set.
      # @return [Array<Object>] Decoded and converted Ruby values.
      def from_payloads(payloads)
        return [] unless payloads && !payloads.payloads.empty?

        if payload_codec && !payloads.payloads.empty?
          payloads = Api::Common::V1::Payloads.new(payloads: payload_codec.decode(payloads.payloads))
        end
        payload_converter.from_payloads(payloads)
      end

      # Convert a Ruby error to a Temporal failure and encode it.
      #
      # @param error [Exception] Ruby error.
      # @return [Api::Failure::V1::Failure] Converted and encoded failure.
      def to_failure(error)
        failure_converter.to_failure(error, self)
      end

      # Decode and convert a Temporal failure to a Ruby error.
      #
      # @param failure [Api::Failure::V1::Failure] Encoded failure.
      # @return [Exception] Decoded and converted Ruby error.
      def from_failure(failure)
        failure_converter.from_failure(failure, self)
      end
    end
  end
end
