# frozen_string_literal: true

require 'google/protobuf'
require 'temporalio/api'
require 'temporalio/converters/payload_converter/encoding'

module Temporalio
  module Converters
    class PayloadConverter
      # Encoding for Protobuf values for +binary/protobuf+ encoding.
      class BinaryProtobuf < Encoding
        ENCODING = 'binary/protobuf'

        # (see Encoding.encoding)
        def encoding
          ENCODING
        end

        # (see Encoding.to_payload)
        def to_payload(value, hint: nil) # rubocop:disable Lint/UnusedMethodArgument
          return nil unless value.is_a?(Google::Protobuf::MessageExts)

          # @type var value: Google::Protobuf::MessageExts
          Api::Common::V1::Payload.new(
            metadata: {
              'encoding' => ENCODING,
              'messageType' => value.class.descriptor.name # steep:ignore NoMethod
            },
            data: value.to_proto
          )
        end

        # (see Encoding.from_payload)
        def from_payload(payload, hint: nil) # rubocop:disable Lint/UnusedMethodArgument
          type = payload.metadata['messageType']
          # @type var desc: untyped
          desc = Google::Protobuf::DescriptorPool.generated_pool.lookup(type)
          raise "No protobuf message found in global pool for message type #{type}" unless desc

          desc.msgclass.decode(payload.data)
        end
      end
    end
  end
end
