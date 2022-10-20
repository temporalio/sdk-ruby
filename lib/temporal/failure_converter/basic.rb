require 'temporal/api/failure/v1/message_pb'
require 'temporal/errors'
require 'temporal/failure_converter/base'

module Temporal
  module FailureConverter
    class Basic
      def initialize(payload_converter)
        @payload_converter = payload_converter
      end

      def to_failure(error)
        Temporal::Api::Failure::V1::Failure.new(message: error.message)
      end

      def from_failure(failure)
        StandardError.new(failure.message)
      end

      private

      attr_reader :payload_converter
    end
  end
end
