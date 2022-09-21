# TODO: This is a dummy converter, a proper implementation will follow
module Temporal
  class Converter
    JSON_ENCODING = 'json/plain'.freeze

    def to_payloads(data)
      return if data.nil? || Array(data).empty?

      payloads = Array(data).map(&method(:to_payload))
      Temporal::Api::Common::V1::Payloads.new(payloads: payloads)
    end

    def to_payload_map(data)
      data&.transform_values(&method(:to_payload))
    end

    def from_payloads(payloads)
      return unless payloads

      payloads.payloads.map(&method(:from_payload))
    end

    def from_payload_map(payload_map)
      return unless payload_map

      payload_map.to_h { |key, value| [key, from_payload(value)] } # rubocop:disable Style/HashTransformValues
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
