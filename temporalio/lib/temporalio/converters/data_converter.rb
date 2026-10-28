# frozen_string_literal: true

require 'temporalio/api'
require 'temporalio/converters/external_storage'
require 'temporalio/converters/failure_converter'
require 'temporalio/converters/payload_codec'
require 'temporalio/converters/payload_converter'
require 'temporalio/internal/external_storage_runner'

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

      # @return [ExternalStorage, nil] Optional storage for offloading large payloads.
      #
      # @note WARNING: This API is experimental and may change in the future.
      #
      # @!visibility private
      attr_reader :external_storage

      # @return [DataConverter] Default data converter.
      def self.default
        @default ||= DataConverter.new
      end

      # Create data converter.
      #
      # @param payload_converter [PayloadConverter] Payload converter to use.
      # @param failure_converter [FailureConverter] Failure converter to use.
      # @param payload_codec [PayloadCodec, nil] Payload codec to use.
      # @param external_storage [ExternalStorage, nil] External storage to use. WARNING: This is experimental.
      def initialize(
        payload_converter: PayloadConverter.default,
        failure_converter: FailureConverter.default,
        payload_codec: nil,
        external_storage: nil
      )
        @payload_converter = payload_converter
        @failure_converter = failure_converter
        @payload_codec = payload_codec
        @external_storage = external_storage
        # Storage is applied in the payload methods below so every client and activity call gets it without changes at
        # each call site. This is temporary. It will move to the call sites as a pass over each whole request, which
        # batches all of a request's payloads into one driver call and can tell drivers which execution they belong to.
        # Retrieving runs even without storage, so a reference is reported rather than decoded as an ordinary value.
        @external_storage_runner = Internal::ExternalStorageRunner.new(external_storage)
      end

      # Convert a Ruby value to a payload and encode it.
      #
      # @param value [Object] Ruby value.
      # @param hint [Object, nil] Hint, if any, to assist conversion.
      # @return [Api::Common::V1::Payload] Converted and encoded payload.
      def to_payload(value, hint: nil)
        payload = payload_converter.to_payload(value, hint:)
        payload = payload_codec.encode([payload]).first if payload_codec
        payload = @external_storage_runner.store([payload]).first if external_storage
        payload
      end

      # Convert multiple Ruby values to a payload set and encode it.
      #
      # @param values [Object] Ruby values, converted to array via {::Array}.
      # @param hints [Array<Object>, nil] Hints, if any, to assist conversion. Note, when using the default converter
      #   that converts a payload at a time, hints for each value are taken from the array at that value's index. So if
      #   there are fewer hints than values, some values will not have a hint. Similarly if there are more hints than
      #   values, the trailing hints are not used.
      # @return [Api::Common::V1::Payloads] Converted and encoded payload set.
      def to_payloads(values, hints: nil)
        payloads = payload_converter.to_payloads(values, hints:)
        payloads.payloads.replace(payload_codec.encode(payloads.payloads)) if payload_codec && !payloads.payloads.empty?
        if external_storage && !payloads.payloads.empty?
          payloads.payloads.replace(@external_storage_runner.store(payloads.payloads.to_a))
        end
        payloads
      end

      # Decode and convert a payload to a Ruby value.
      #
      # @param payload [Api::Common::V1::Payload] Encoded payload.
      # @param hint [Object, nil] Hint, if any, to assist conversion.
      # @return [Object] Decoded and converted Ruby value.
      def from_payload(payload, hint: nil)
        payload = @external_storage_runner.retrieve([payload]).first
        payload = payload_codec.decode([payload]).first if payload_codec
        payload_converter.from_payload(payload, hint:)
      end

      # Decode and convert a payload set to Ruby values.
      #
      # @param payloads [Api::Common::V1::Payloads, nil] Encoded payload set.
      # @param hints [Array<Object>, nil] Hints, if any, to assist conversion. Note, when using the default converter
      #   that converts a value at a time, hints for each payload are taken from the array at that payload's index. So
      #   if there are fewer hints than payloads, some payloads will not have a hint. Similarly if there are more hints
      #   than payloads, the trailing hints are not used.
      # @return [Array<Object>] Decoded and converted Ruby values.
      def from_payloads(payloads, hints: nil)
        return [] unless payloads && !payloads.payloads.empty?

        payloads = Api::Common::V1::Payloads.new(payloads: @external_storage_runner.retrieve(payloads.payloads.to_a))
        if payload_codec && !payloads.payloads.empty?
          payloads = Api::Common::V1::Payloads.new(payloads: payload_codec.decode(payloads.payloads))
        end
        payload_converter.from_payloads(payloads, hints:)
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
