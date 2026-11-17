# frozen_string_literal: true

require 'temporalio/internal/bridge/api'
require 'temporalio/internal/proto_utils'

module Temporalio
  module Internal
    # Gathers what external storage moved during one store or retrieve pass, for core to report on the activation
    # completion.
    #
    # @!visibility private
    class StorageOperationMetrics
      def initialize
        @mutex = Mutex.new
        @payload_count = 0
        @total_size_bytes = 0
        @driver_names = Set.new
        @spans = []
      end

      # Record one driver call that moved payloads.
      #
      # @param driver_name [String] Driver that stored or retrieved the payloads.
      # @param payload_count [Integer] Number of payloads moved.
      # @param total_size_bytes [Integer] Encoded size of the payloads moved.
      # @param start_time [Float] Monotonic clock reading taken before the driver call.
      # @param end_time [Float] Monotonic clock reading taken after the driver call.
      def record(driver_name:, payload_count:, total_size_bytes:, start_time:, end_time:)
        @mutex.synchronize do
          @driver_names << driver_name
          @payload_count += payload_count
          @total_size_bytes += total_size_bytes
          @spans << [start_time, end_time]
        end
      end

      # @return [Bridge::Api::Common::ExternalStorageMetrics, nil] Metrics for the pass, or nil when it moved nothing,
      #   so the completion field stays unset.
      def to_proto
        @mutex.synchronize do
          return nil if @payload_count.zero?

          Bridge::Api::Common::ExternalStorageMetrics.new(
            payload_count: @payload_count,
            total_size_bytes: @total_size_bytes,
            total_duration: ProtoUtils.seconds_to_duration(union_seconds),
            driver_names: @driver_names.sort
          )
        end
      end

      private

      def union_seconds
        first, *rest = @spans.sort
        return 0.0 unless first

        total = 0.0
        span_start, span_end = first
        rest.each do |start_time, end_time|
          if start_time > span_end
            total += span_end - span_start
            span_start = start_time
            span_end = end_time
          elsif end_time > span_end
            span_end = end_time
          end
        end
        total + (span_end - span_start)
      end
    end
  end
end
