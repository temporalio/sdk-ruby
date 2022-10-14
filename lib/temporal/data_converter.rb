require 'temporal/payload_converter'

module Temporal
  class DataConverter
    def initialize(payload_converter: Temporal::PayloadConverter::DEFAULT)
      @payload_converter = payload_converter
    end

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

    attr_reader :payload_converter

    def to_payload(data)
      payload_converter.to_payload(data)
    end

    def from_payload(payload)
      payload_converter.from_payload(payload)
    end
  end
end
