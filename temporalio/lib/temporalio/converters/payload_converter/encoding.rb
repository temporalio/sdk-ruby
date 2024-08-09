# frozen_string_literal: true

module Temporalio
  module Converters
    class PayloadConverter
      # Base class for encoding converters that can be used for {Composite} converters. Each converter has an {encoding}
      # that should be set on the Payload metadata for values it can process. Implementers must implement {encoding}
      class Encoding
        # @return [String] Encoding that will be put on the payload metadata if this encoding converter can handle the
        #   value.
        def encoding
          raise NotImplementedError
        end

        # Convert value to payload if this encoding converter can handle it, or return +nil+. If the converter can
        # handle it, the resulting payload must have +encoding+ metadata on the payload set to the value of {encoding}.
        #
        # @param value [Object] Ruby value to possibly convert.
        # @return [Api::Common::V1::Payload, nil] Converted payload if it can handle it, +nil+ otherwise.
        def to_payload(value)
          raise NotImplementedError
        end

        # Convert the payload to a Ruby value. The caller confirms the +encoding+ metadata matches {encoding}, so this
        # will error if it cannot convert.
        #
        # @param payload [Api::Common::V1::Payload] Payload to convert.
        # @return [Object] Converted Ruby value.
        def from_payload(payload)
          raise NotImplementedError
        end
      end
    end
  end
end
