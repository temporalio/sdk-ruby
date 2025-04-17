# frozen_string_literal: true

module Temporalio
  module Internal
    module Bridge
      class Runtime
        Options = Struct.new(
          :telemetry,
          keyword_init: true
        )

        TelemetryOptions = Struct.new(
          :logging, # Optional
          :metrics, # Optional
          keyword_init: true
        )

        LoggingOptions = Struct.new(
          :log_filter,
          :forward_to, # Optional
          keyword_init: true
        )

        MetricsOptions = Struct.new(
          :opentelemetry, # Optional
          :prometheus, # Optional
          :buffered_with_size, # Optional
          :attach_service_name,
          :global_tags, # Optional
          :metric_prefix, # Optional
          keyword_init: true
        )

        OpenTelemetryMetricsOptions = Struct.new(
          :url,
          :headers, # Optional
          :metric_periodicity, # Optional
          :metric_temporality_delta,
          :durations_as_seconds,
          :http,
          :histogram_bucket_overrides, # Optional
          keyword_init: true
        )

        PrometheusMetricsOptions = Struct.new(
          :bind_address,
          :counters_total_suffix,
          :unit_suffix,
          :durations_as_seconds,
          :histogram_bucket_overrides, # Optional
          keyword_init: true
        )
      end
    end
  end
end
