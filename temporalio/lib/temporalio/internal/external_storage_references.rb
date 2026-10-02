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

      class << self
        # @param payload [Api::Common::V1::Payload] Payload to check.
        # @return [Boolean] Whether the payload is a reference to externally stored data.
        def reference?(payload)
          payload.metadata['encoding'] == ENCODING && payload.metadata['messageType'] == MESSAGE_TYPE
        end

        # @param payload [Api::Common::V1::Payload] Payload to parse.
        # @return [Api::Sdk::V1::ExternalStorageReference, nil] Parsed reference, or nil if not a reference.
        def parse_reference(payload)
          return nil unless reference?(payload)

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
