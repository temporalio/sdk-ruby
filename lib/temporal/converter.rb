require 'json'

# TODO: This is a dummy converter, a proper implementation will follow
module Temporal
  class Converter
    JSON_ENCODING = 'json/plain'.freeze

    def to_payloads(data)
      return if data.nil? || Array(data).empty?

      payloads = Array(data).map { |value| to_payload(value) }
      Temporal::Api::Common::V1::Payloads.new(payloads: payloads)
    end

    def to_payload_map(data)
      data.to_h { |key, value| [key.to_s, to_payload(value)] }
    end

    def from_payloads(payloads)
      return unless payloads

      payloads.payloads.map { |payload| from_payload(payload) }
    end

    def from_payload_map(payload_map)
      return unless payload_map

      # Protobuf's Hash isn't compatible with the native Hash, ignore rubocop here
      # rubocop:disable Style/HashTransformValues, Style/MapToHash
      payload_map.map { |key, value| [key, from_payload(value)] }.to_h
      # rubocop:enable Style/HashTransformValues, Style/MapToHash
    end

    private

    def to_payload(data)
      Temporal::Api::Common::V1::Payload.new(
        metadata: { 'encoding' => JSON_ENCODING },
        data: JSON.generate(data).b,
      )
    end

    def from_payload(payload)
      if payload.metadata['encoding'] == JSON_ENCODING
        JSON.parse(payload.data)
      end
    end
  end
end
