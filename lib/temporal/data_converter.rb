require 'temporal/api/common/v1/message_pb'
require 'temporal/errors'

module Temporal
  class DataConverter
    class MissingPayload < Temporal::Error; end

    def initialize(payload_converter:, payload_codecs:, failure_converter:)
      @payload_converter = payload_converter
      @payload_codecs = payload_codecs
      @failure_converter = failure_converter
    end

    def to_payload(value)
      payload = value_to_payload(value)
      encoded_payload = encode([payload]).first
      raise MissingPayload, 'Payload Codecs returned no payloads' unless encoded_payload

      encoded_payload
    end

    def to_payloads(data)
      return if data.nil? || Array(data).empty?

      payloads = Array(data).map { |value| value_to_payload(value) }
      Temporal::Api::Common::V1::Payloads.new(payloads: encode(payloads))
    end

    def to_payload_map(data)
      data.to_h do |key, value|
        [key.to_s, to_payload(value)]
      end
    end

    def to_failure(error)
      failure = failure_converter.to_failure(error, payload_converter)
      encode_failure(failure)
    end

    def from_payload(payload)
      decoded_payload = decode([payload]).first
      raise MissingPayload, 'Payload Codecs returned no payloads' unless decoded_payload

      payload_to_value(decoded_payload)
    end

    def from_payloads(payloads)
      return unless payloads

      decode(payloads.payloads)
        .map { |payload| payload_to_value(payload) }
    end

    def from_payload_map(payload_map)
      return unless payload_map

      # Protobuf's Hash isn't compatible with the native Hash, ignore rubocop here
      # rubocop:disable Style/MapToHash, Style/HashTransformValues
      payload_map.map do |key, payload|
        [key, from_payload(payload)]
      end.to_h
      # rubocop:enable Style/MapToHash, Style/HashTransformValues
    end

    def from_failure(failure)
      raise ArgumentError, 'missing a failure to convert from' unless failure

      failure = decode_failure(failure)
      failure_converter.from_failure(failure, payload_converter)
    end

    private

    attr_reader :payload_converter, :payload_codecs, :failure_converter

    def value_to_payload(value)
      payload_converter.to_payload(value)
    end

    def payload_to_value(payload)
      payload_converter.from_payload(payload)
    end

    def encode(payloads)
      return [] unless payloads

      payload_codecs.each do |codec|
        payloads = codec.encode(payloads)
      end

      payloads
    end

    def decode(payloads)
      return [] unless payloads

      payload_codecs.reverse_each do |codec|
        payloads = codec.decode(payloads)
      end

      payloads
    end

    def encode_failure(failure)
      failure = failure.dup

      failure.encoded_attributes = failure.encoded_attributes ? encode([failure.encoded_attributes])&.first : nil
      failure.cause = failure.cause ? encode_failure(failure.cause) : nil

      if failure.application_failure_info
        failure.application_failure_info.details = Temporal::Api::Common::V1::Payloads.new(
          payloads: encode(failure.application_failure_info.details&.payloads).to_a,
        )
      elsif failure.timeout_failure_info
        failure.timeout_failure_info.last_heartbeat_details = Temporal::Api::Common::V1::Payloads.new(
          payloads: encode(failure.timeout_failure_info.last_heartbeat_details&.payloads).to_a,
        )
      elsif failure.canceled_failure_info
        failure.canceled_failure_info.details = Temporal::Api::Common::V1::Payloads.new(
          payloads: encode(failure.canceled_failure_info.details&.payloads).to_a,
        )
      elsif failure.reset_workflow_failure_info
        failure.reset_workflow_failure_info.last_heartbeat_details = Temporal::Api::Common::V1::Payloads.new(
          payloads: encode(failure.reset_workflow_failure_info.last_heartbeat_details&.payloads).to_a,
        )
      end

      failure
    end

    def decode_failure(failure)
      failure = failure.dup

      failure.encoded_attributes = failure.encoded_attributes ? decode([failure.encoded_attributes])&.first : nil
      failure.cause = failure.cause ? decode_failure(failure.cause) : nil

      if failure.application_failure_info
        failure.application_failure_info.details = Temporal::Api::Common::V1::Payloads.new(
          payloads: decode(failure.application_failure_info.details&.payloads).to_a,
        )
      elsif failure.timeout_failure_info
        failure.timeout_failure_info.last_heartbeat_details = Temporal::Api::Common::V1::Payloads.new(
          payloads: decode(failure.timeout_failure_info.last_heartbeat_details&.payloads).to_a,
        )
      elsif failure.canceled_failure_info
        failure.canceled_failure_info.details = Temporal::Api::Common::V1::Payloads.new(
          payloads: decode(failure.canceled_failure_info.details&.payloads).to_a,
        )
      elsif failure.reset_workflow_failure_info
        failure.reset_workflow_failure_info.last_heartbeat_details = Temporal::Api::Common::V1::Payloads.new(
          payloads: decode(failure.reset_workflow_failure_info.last_heartbeat_details&.payloads).to_a,
        )
      end

      failure
    end
  end
end
