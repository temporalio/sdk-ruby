# frozen_string_literal: true

module Temporalio
  module Internal
    module Bridge
      class Runtime
        Options = Struct.new(
          :telemetry,
          :worker_heartbeat_interval
        )

        TelemetryOptions = Struct.new(
          :logging, # Optional
          :metrics # Optional
        )

        LoggingOptions = Struct.new(
          :log_filter,
          :forward_to # Optional
        )

        MetricsOptions = Struct.new(
          :opentelemetry, # Optional
          :prometheus, # Optional
          :buffered_with_size, # Optional
          :attach_service_name,
          :global_tags, # Optional
          :metric_prefix # Optional
        )

        OpenTelemetryMetricsOptions = Struct.new(
          :url,
          :headers, # Optional
          :metric_periodicity, # Optional
          :metric_temporality_delta,
          :durations_as_seconds,
          :http,
          :histogram_bucket_overrides # Optional
        )

        PrometheusMetricsOptions = Struct.new(
          :bind_address,
          :counters_total_suffix,
          :unit_suffix,
          :durations_as_seconds,
          :histogram_bucket_overrides # Optional
        )
      end
    end
  end
end
