# frozen_string_literal: true

require 'temporalio/api'

module Temporalio
  module Internal
    # @!visibility private
    module ProtoUtils
      # @!visibility private
      def self.seconds_to_duration(seconds_float)
        return nil if seconds_float.nil?

        seconds = seconds_float.to_i
        nanos = ((seconds_float - seconds) * 1_000_000_000).round
        Google::Protobuf::Duration.new(seconds:, nanos:)
      end

      # @!visibility private
      def self.memo_to_proto(hash, data_converter)
        return nil if hash.nil?

        Api::Common::V1::Memo.new(fields: hash.transform_values { |val| data_converter.to_payload(val) })
      end
    end
  end
end
