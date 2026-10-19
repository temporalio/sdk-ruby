# frozen_string_literal: true

require 'temporalio/api'
require 'temporalio/api/sdk/v1/external_storage'

module Temporalio
  module Internal
    # The on-the-wire form of a payload that has been offloaded to external storage.
    #
    # An offloaded payload is replaced by one whose data is the proto-JSON form of an
    # +ExternalStorageReference+. This shape is part of the wire contract and must not be changed unilaterally.
    #
    # @!visibility private
    module ExternalStorageReferences
      ENCODING = 'json/protobuf'
      MESSAGE_TYPE = 'temporal.api.sdk.v1.ExternalStorageReference'
      MARKER = '__temporal_external_storage_reference'
      MARKER_VALUE = 'true'

      class << self
        # Reads metadata only, so no payload is decoded and one that needs no retrieval is not touched.
        #
        # @param payload [Api::Common::V1::Payload] Payload to check.
        # @return [Boolean] Whether the payload has to be retrieved from external storage.
        def needs_retrieval?(payload)
          marked?(payload) || plain_reference?(payload)
        end

        # A marked payload that a codec encoded must be decoded before it is parsed.
        #
        # Both halves are required: +json/protobuf+ on its own is an ordinary encoding for any protobuf payload.
        #
        # @param payload [Api::Common::V1::Payload] Payload to check.
        # @return [Boolean] Whether the payload is a reference in the form a codec has not encoded.
        def plain_reference?(payload)
          payload.metadata['encoding'] == ENCODING && payload.metadata['messageType'] == MESSAGE_TYPE
        end

        # The value is checked, not just the key.
        #
        # @param payload [Api::Common::V1::Payload] Payload to check.
        # @return [Boolean] Whether the payload carries the reference marker.
        def marked?(payload)
          payload.metadata[MARKER] == MARKER_VALUE
        end

        # The SDK does this after the codec has encoded the reference, so the marker lands on the outermost
        # payload. With no codec configured the reference is itself outermost and is marked just the same.
        #
        # @param payload [Api::Common::V1::Payload] Reference payload to mark, modified in place.
        def mark(payload)
          payload.metadata[MARKER] = MARKER_VALUE.b
        end

        # @param payload [Api::Common::V1::Payload] Payload to parse.
        # @return [Api::Sdk::V1::ExternalStorageReference, nil] Parsed reference, or nil if not a plain reference.
        #
        # TODO: Surface parse failures as a Temporal error instead of Google::Protobuf::ParseError. The runner is the
        # right layer for it, since only the caller knows which payload failed; a malformed reference cannot name its
        # own driver.
        def parse_reference(payload)
          return nil unless plain_reference?(payload)

          # Another SDK may add fields to the reference before this one knows about them, and an unknown field must
          # not make an otherwise-valid payload unreadable.
          Api::Sdk::V1::ExternalStorageReference.decode_json(
            payload.data, ignore_unknown_fields: true
          )
        end

        # @param driver_name [String] Name of the driver that stored the payload.
        # @param claim_data [Hash<String, String>] Driver data identifying the stored payload.
        # @param original_size_bytes [Integer] Encoded size of the payload that was offloaded.
        # @return [Api::Common::V1::Payload] Reference payload that replaces the offloaded payload on the wire.
        def create_reference_payload(driver_name:, claim_data:, original_size_bytes:)
          reference = Api::Sdk::V1::ExternalStorageReference.new(
            driver_name:, claim_data: claim_data.to_h
          )
          Api::Common::V1::Payload.new(
            metadata: { 'encoding' => ENCODING.b, 'messageType' => MESSAGE_TYPE.b },
            data: reference.to_json.b,
            # The original size is kept so the server and UI can report what the payload would have been without
            # having to fetch it from storage.
            external_payloads: [
              Api::Common::V1::Payload::ExternalPayloadDetails.new(size_bytes: original_size_bytes)
            ]
          )
        end
      end
    end
  end
end
