require 'temporal/api/common/v1/message_pb'
require 'temporal/errors'
require 'temporal/payload_converter'

module Temporal
  class DataConverter
    class MissingPayload < Temporal::Error; end

    def initialize(payload_converter: Temporal::PayloadConverter::DEFAULT, payload_codecs: [])
      @payload_converter = payload_converter
      @payload_codecs = payload_codecs
    end

    def to_payloads(data)
      return if data.nil? || Array(data).empty?

      payloads = Array(data).map { |value| to_payload(value) }
      Temporal::Api::Common::V1::Payloads.new(payloads: encode(payloads))
    end

    def to_payload_map(data)
      data.to_h do |key, value|
        payload = to_payload(value)
        encoded_payload = encode([payload]).first
        raise MissingPayload, 'Payload Codecs returned no payloads' unless encoded_payload

        [key.to_s, encoded_payload]
      end
    end

    def from_payloads(payloads)
      return unless payloads

      decode(payloads.payloads)
        .map { |payload| from_payload(payload) }
    end

    def from_payload_map(payload_map)
      return unless payload_map

      # Protobuf's Hash isn't compatible with the native Hash, ignore rubocop here
      # rubocop:disable Style/MapToHash
      payload_map.map do |key, payload|
        decoded_payload = decode([payload]).first
        raise MissingPayload, 'Payload Codecs returned no payloads' unless decoded_payload

        [key, from_payload(decoded_payload)]
      end.to_h
      # rubocop:enable Style/MapToHash
    end

    private

    attr_reader :payload_converter, :payload_codecs

    def encode(payloads)
      payload_codecs.each do |codec|
        payloads = codec.encode(payloads)
      end

      payloads
    end

    def decode(payloads)
      payload_codecs.reverse_each do |codec|
        payloads = codec.decode(payloads)
      end

      payloads
    end

    def to_payload(data)
      payload_converter.to_payload(data)
    end

    def from_payload(payload)
      payload_converter.from_payload(payload)
    end
  end
end
