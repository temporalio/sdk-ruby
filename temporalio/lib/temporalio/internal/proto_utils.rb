# frozen_string_literal: true

require 'temporalio/api'

module Temporalio
  module Internal
    module ProtoUtils
      def self.seconds_to_duration(seconds_numeric)
        return nil if seconds_numeric.nil?

        seconds = seconds_numeric.to_i
        nanos = ((seconds_numeric - seconds) * 1_000_000_000).round
        Google::Protobuf::Duration.new(seconds:, nanos:)
      end

      def self.duration_to_seconds(duration)
        return nil if duration.nil?

        # This logic was corrected for timestamp at
        # https://github.com/protocolbuffers/protobuf/pull/2482 but not for
        # duration, so 4.56 is not properly represented in to_f, it becomes
        # 4.5600000000000005.
        (duration.seconds + duration.nanos.quo(1_000_000_000)).to_f
      end

      def self.time_to_timestamp(time)
        return nil if time.nil?

        Google::Protobuf::Timestamp.from_time(time)
      end

      def self.timestamp_to_time(timestamp)
        return nil if timestamp.nil?

        # The regular to_time on the timestamp converts to local timezone,
        # and we prefer not to make a separate .utc call (converts to local
        # then back to UTC unnecessarily)
        Time.at(timestamp.seconds, timestamp.nanos, :nanosecond, in: 'UTC')
      end

      def self.memo_to_proto(hash, converter)
        return nil if hash.nil? || hash.empty?

        Api::Common::V1::Memo.new(fields: memo_to_proto_hash(hash, converter))
      end

      def self.memo_to_proto_hash(hash, converter)
        return nil if hash.nil? || hash.empty?

        hash.transform_keys(&:to_s).transform_values { |val| converter.to_payload(val) }
      end

      def self.memo_from_proto(memo, converter)
        return nil if memo.nil? || memo.fields.size.zero? # rubocop:disable Style/ZeroLengthPredicate Google Maps don't have empty

        memo.fields.each_with_object({}) { |(key, val), h| h[key] = converter.from_payload(val) } # rubocop:disable Style/HashTransformValues
      end

      def self.headers_to_proto(headers, converter)
        return nil if headers.nil? || headers.empty?

        Api::Common::V1::Header.new(fields: headers.transform_values { |val| converter.to_payload(val) })
      end

      def self.headers_from_proto(headers, converter)
        headers_from_proto_map(headers&.fields, converter)
      end

      def self.headers_from_proto_map(headers, converter)
        return nil if headers.nil? || headers.size.zero? # rubocop:disable Style/ZeroLengthPredicate Google Maps don't have empty

        headers.each_with_object({}) do |(key, val), h| # rubocop:disable Style/HashTransformValues
          # @type var h: Hash[String, Object?]
          h[key] = converter.from_payload(val)
        end
      end

      def self.string_or(str, default = nil)
        str && !str.empty? ? str : default
      end

      def self.enum_to_int(enum_mod, enum_val, zero_means_nil: false)
        # Per https://protobuf.dev/reference/ruby/ruby-generated/#enum when
        # enums are read back, they are symbols if they are known or number
        # otherwise
        enum_val = enum_mod.resolve(enum_val) || raise('Unexpected missing symbol') if enum_val.is_a?(Symbol)
        enum_val = nil if zero_means_nil && enum_val.zero?
        enum_val
      end

      def self.convert_from_payload_array(converter, payloads)
        return [] if payloads.empty?

        converter.from_payloads(Api::Common::V1::Payloads.new(payloads:))
      end

      def self.convert_to_payload_array(converter, values)
        return [] if values.empty?

        converter.to_payloads(values).payloads.to_ary
      end

      class LazyMemo
        def initialize(raw_memo, converter)
          @raw_memo = raw_memo
          @converter = converter
        end

        def get
          @memo = ProtoUtils.memo_from_proto(@raw_memo, @converter) unless defined?(@memo)
          @memo
        end
      end

      class LazySearchAttributes
        def initialize(raw_search_attributes)
          @raw_search_attributes = raw_search_attributes
        end

        def get
          @search_attributes = SearchAttributes._from_proto(@raw_search_attributes) unless defined?(@search_attributes)
          @search_attributes
        end
      end
    end
  end
end
