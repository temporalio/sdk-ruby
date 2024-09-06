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
      def self.memo_to_proto(hash, converter)
        return nil if hash.nil?

        Api::Common::V1::Memo.new(fields: hash.transform_values { |val| converter.to_payload(val) })
      end

      # @!visibility private
      def self.memo_from_proto(memo, converter)
        return nil if memo.nil?

        memo.fields.each_with_object({}) { |(key, val), h| h[key] = converter.from_payload(val) } # rubocop:disable Style/HashTransformValues
      end

      # @!visibility private
      def self.string_or(str, default = nil)
        str && !str.empty? ? str : default
      end

      # @!visibility private
      def self.enum_to_int(enum_mod, enum_val, zero_means_nil: false)
        # Per https://protobuf.dev/reference/ruby/ruby-generated/#enum when
        # enums are read back, they are symbols if they are known or number
        # otherwise
        enum_val = enum_mod.resolve(enum_val) || raise('Unexpected missing symbol') if enum_val.is_a?(Symbol)
        enum_val = nil if zero_means_nil && enum_val.zero?
        enum_val
      end
    end
  end
end
