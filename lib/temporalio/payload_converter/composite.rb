require 'temporalio/payload_converter/base'
require 'temporalio/errors'

module Temporalio
  module PayloadConverter
    # A payload converter for combining multiple payload converters together.
    class Composite < Base
      class ConverterNotFound < Temporalio::Error; end
      class EncodingNotSet < Temporalio::Error; end

      # @param converters [Array<Temporalio::PayloadConverter::Base>] List of converters
      def initialize(*converters)
        super()

        @converters = converters.each_with_object({}) do |converter, result|
          result[converter.encoding] = converter
          result
        end
      end

      def to_payload(data)
        converters.each_value do |converter|
          payload = converter.to_payload(data)
          return payload unless payload.nil?
        end

        available = converters.values.map(&:class).join(', ')
        raise ConverterNotFound, "Available converters (#{available}) could not convert data"
      end

      def from_payload(payload)
        encoding = payload.metadata['encoding']
        raise EncodingNotSet, 'Missing payload encoding' unless encoding

        converter = converters[encoding]
        unless converter
          available = converters.keys.join(', ')
          raise ConverterNotFound, "Missing converter for encoding '#{encoding}' (available: #{available})"
        end

        converter.from_payload(payload)
      end

      private

      attr_reader :converters
    end
  end
end
