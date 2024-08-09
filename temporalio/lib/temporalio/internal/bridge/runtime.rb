# frozen_string_literal: true

module Temporalio
  module Internal
    module Bridge
      # @!visibility private
      class Runtime
        # @!visibility private
        Options = Struct.new(
          :telemetry,
          keyword_init: true
        )

        # @!visibility private
        TelemetryOptions = Struct.new(
          :logging, # Optional
          :metrics, # Optional
          keyword_init: true
        )

        # @!visibility private
        LoggingOptions = Struct.new(
          :log_filter,
          :forward_to, # Optional
          keyword_init: true
        )

        # @!visibility private
        MetricsOptions = Struct.new(
          :opentelemetry, # Optional
          :prometheus, # Optional
          :buffered_with_size, # Optional
          :attach_service_name,
          :global_tags, # Optional
          :metric_prefix, # Optional
          keyword_init: true
        )

        # @!visibility private
        OpenTelemetryMetricsOptions = Struct.new(
          :url,
          :headers, # Optional
          :metric_periodicity, # Optional
          :metric_temporality_delta,
          :durations_as_seconds,
          keyword_init: true
        )

        # @!visibility private
        PrometheusOptions = Struct.new(
          :bind_address,
          :counters_total_suffix,
          :unit_suffix,
          :durations_as_seconds,
          keyword_init: true
        )
      end
    end
  end
end
