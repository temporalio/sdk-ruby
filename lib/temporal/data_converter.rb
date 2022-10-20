require 'temporal/api/common/v1/message_pb'
require 'temporal/errors'
require 'temporal/payload_converter'
require 'temporal/failure_converter'

module Temporal
  class DataConverter
    class MissingPayload < Temporal::Error; end

    def initialize(
      payload_converter: Temporal::PayloadConverter::DEFAULT,
      payload_codecs: [],
      failure_converter: Temporal::FailureConverter::DEFAULT
    )
      @payload_converter = payload_converter
      @payload_codecs = payload_codecs
      @failure_converter = failure_converter
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

    def to_failure(error)
      failure = failure_converter.to_failure(error)
      encode_failure(failure)
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

    def from_failure(failure)
      failure = decode_failure(failure)
      failure_converter.from_failure(failure)
    end

    private

    attr_reader :payload_converter, :payload_codecs, :failure_converter

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

    def to_payload(data)
      payload_converter.to_payload(data)
    end

    def from_payload(payload)
      payload_converter.from_payload(payload)
    end

    def encode_failure(failure)
      failure = failure.dup

      failure.encoded_attributes = failure.encoded_attributes ? encode([failure.encoded_attributes])&.first : nil
      failure.cause = failure.cause ? encode_failure(failure.cause) : nil

      if failure.application_failure_info
        failure.application_failure_info.details&.payloads =
          encode(failure.application_failure_info.details&.payloads)
      elsif failure.timeout_failure_info
        failure.timeout_failure_info.last_heartbeat_details&.payloads =
          encode(failure.timeout_failure_info.last_heartbeat_details&.payloads)
      elsif failure.canceled_failure_info
        failure.canceled_failure_info.details&.payloads =
          encode(failure.canceled_failure_info.details&.payloads)
      elsif failure.reset_workflow_failure_info
        failure.reset_workflow_failure_info.last_heartbeat_details&.payloads =
          encode(failure.reset_workflow_failure_info.last_heartbeat_details&.payloads)
      end

      failure
    end

    def decode_failure(failure)
      failure = failure.dup

      failure.encoded_attributes = failure.encoded_attributes ? decode([failure.encoded_attributes])&.first : nil
      failure.cause = failure.cause ? decode_failure(failure.cause) : nil

      if failure.application_failure_info
        failure.application_failure_info.details&.payloads =
          decode(failure.application_failure_info.details&.payloads)
      elsif failure.timeout_failure_info
        failure.timeout_failure_info.last_heartbeat_details&.payloads =
          decode(failure.timeout_failure_info.last_heartbeat_details&.payloads)
      elsif failure.canceled_failure_info
        failure.canceled_failure_info.details&.payloads =
          decode(failure.canceled_failure_info.details&.payloads)
      elsif failure.reset_workflow_failure_info
        failure.reset_workflow_failure_info.last_heartbeat_details&.payloads =
          decode(failure.reset_workflow_failure_info.last_heartbeat_details&.payloads)
      end

      failure
    end
  end
end
