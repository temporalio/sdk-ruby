# frozen_string_literal: true

require 'temporalio/internal/bridge'
require 'temporalio/internal/bridge/runtime'
require 'temporalio/internal/metric'
require 'temporalio/metric'

module Temporalio
  # Runtime for Temporal Ruby SDK.
  #
  # Only one global {Runtime} needs to exist. Users are encouraged to use {default}. To configure it, create a runtime
  # before any clients are created, and set it via {default=}. Every time a new runtime is created, a new internal Rust
  # thread pool is created.
  class Runtime
    TelemetryOptions = Struct.new(
      :logging,
      :metrics,
      keyword_init: true
    )

    # Telemetry options for the runtime.
    #
    # @!attribute logging
    #   @return [LoggingOptions, nil] Logging options, default is new {LoggingOptions} with no parameters. Can be set
    #     to nil to disable logging.
    # @!attribute metrics
    #   @return [MetricsOptions, nil] Metrics options.
    class TelemetryOptions
      # Create telemetry options.
      #
      # @param logging [LoggingOptions, nil] Logging options, default is new {LoggingOptions} with no parameters. Can be
      #   set to nil to disable logging.
      # @param metrics [MetricsOptions, nil] Metrics options.
      def initialize(logging: LoggingOptions.new, metrics: nil)
        super
      end

      # @!visibility private
      def _to_bridge
        # @type self: TelemetryOptions
        Internal::Bridge::Runtime::TelemetryOptions.new(
          logging: logging&._to_bridge,
          metrics: metrics&._to_bridge
        )
      end
    end

    LoggingOptions = Struct.new(
      :log_filter,
      # TODO(cretz): forward_to
      keyword_init: true
    )

    # Logging options for runtime telemetry.
    #
    # @!attribute log_filter
    #   @return [LoggingFilterOptions, String] Logging filter for Core, default is new {LoggingFilterOptions} with no
    #     parameters.
    class LoggingOptions
      # Create logging options
      #
      # @param log_filter [LoggingFilterOptions, String] Logging filter for Core.
      def initialize(log_filter: LoggingFilterOptions.new)
        super
      end

      # @!visibility private
      def _to_bridge
        # @type self: LoggingOptions
        Internal::Bridge::Runtime::LoggingOptions.new(
          log_filter: if log_filter.is_a?(String)
                        log_filter
                      elsif log_filter.is_a?(LoggingFilterOptions)
                        log_filter._to_bridge
                      else
                        raise 'Log filter must be string or LoggingFilterOptions'
                      end
        )
      end
    end

    LoggingFilterOptions = Struct.new(
      :core_level,
      :other_level,
      keyword_init: true
    )

    # Logging filter options for Core.
    #
    # @!attribute core_level
    #   @return ['TRACE', 'DEBUG', 'INFO', 'WARN', 'ERROR'] Log level for Core log messages.
    # @!attribute other_level
    #   @return ['TRACE', 'DEBUG', 'INFO', 'WARN', 'ERROR'] Log level for other Rust log messages.
    class LoggingFilterOptions
      # Create logging filter options.
      #
      # @param core_level ['TRACE', 'DEBUG', 'INFO', 'WARN', 'ERROR'] Log level for Core log messages.
      # @!attribute other_level ['TRACE', 'DEBUG', 'INFO', 'WARN', 'ERROR'] Log level for other Rust log messages.
      def initialize(core_level: 'WARN', other_level: 'ERROR')
        super
      end

      # @!visibility private
      def _to_bridge
        # @type self: LoggingFilterOptions
        "#{other_level},temporal_sdk_core=#{core_level},temporal_client=#{core_level},temporal_sdk=#{core_level}"
      end
    end

    MetricsOptions = Struct.new(
      :opentelemetry,
      :prometheus,
      :attach_service_name,
      :global_tags,
      :metric_prefix,
      keyword_init: true
    )

    # Metrics options for runtime telemetry. Either {opentelemetry} or {prometheus} required, but not both.
    #
    # @!attribute opentelemetry
    #   @return [OpenTelemetryMetricsOptions, nil] OpenTelemetry options if using OpenTelemetry. This is mutually
    #     exclusive with +prometheus+.
    # @!attribute prometheus
    #   @return [PrometheusMetricsOptions, nil] Prometheus options if using Prometheus. This is mutually exclusive with
    #     +opentelemetry+.
    # @!attribute attach_service_name
    #   @return [Boolean] Whether to put the service_name on every metric.
    # @!attribute global_tags
    #   @return [Hash<String, String>, nil] Resource tags to be applied to all metrics.
    # @!attribute metric_prefix
    #   @return [String, nil] Prefix to put on every Temporal metric. If unset, defaults to `temporal_`.
    class MetricsOptions
      # Create metrics options. Either `opentelemetry` or `prometheus` required, but not both.
      #
      # @param opentelemetry [OpenTelemetryMetricsOptions, nil] OpenTelemetry options if using OpenTelemetry. This is
      #   mutually exclusive with `prometheus`.
      # @param prometheus [PrometheusMetricsOptions, nil] Prometheus options if using Prometheus. This is mutually
      #   exclusive with `opentelemetry`.
      # @param attach_service_name [Boolean] Whether to put the service_name on every metric.
      # @param global_tags [Hash<String, String>, nil] Resource tags to be applied to all metrics.
      # @param metric_prefix [String, nil] Prefix to put on every Temporal metric. If unset, defaults to `temporal_`.
      def initialize(
        opentelemetry: nil,
        prometheus: nil,
        attach_service_name: true,
        global_tags: nil,
        metric_prefix: nil
      )
        super
      end

      # @!visibility private
      def _to_bridge
        # @type self: MetricsOptions
        Internal::Bridge::Runtime::MetricsOptions.new(
          opentelemetry: opentelemetry&._to_bridge,
          prometheus: prometheus&._to_bridge,
          attach_service_name:,
          global_tags:,
          metric_prefix:
        )
      end
    end

    OpenTelemetryMetricsOptions = Struct.new(
      :url,
      :headers,
      :metric_periodicity,
      :metric_temporality,
      :durations_as_seconds,
      keyword_init: true
    )

    # Options for exporting metrics to OpenTelemetry.
    #
    # @!attribute url
    #   @return [String] URL for OpenTelemetry endpoint.
    # @!attribute headers
    #   @return [Hash<String, String>, nil] Headers for OpenTelemetry endpoint.
    # @!attribute metric_periodicity
    #   @return [Float, nil] How frequently metrics should be exported, unset uses internal default.
    # @!attribute metric_temporality
    #   @return [MetricTemporality] How frequently metrics should be exported, default is
    #     {MetricTemporality::CUMULATIVE}.
    # @!attribute durations_as_seconds
    #   @return [Boolean] Whether to use float seconds instead of integer milliseconds for durations, default is
    #     +false+.
    class OpenTelemetryMetricsOptions
      # OpenTelemetry metric temporality.
      module MetricTemporality
        CUMULATIVE = 1
        DELTA = 2
      end

      # Create OpenTelemetry options.
      #
      # @param url [String] URL for OpenTelemetry endpoint.
      # @param headers [Hash<String, String>, nil] Headers for OpenTelemetry endpoint.
      # @param metric_periodicity [Float, nil] How frequently metrics should be exported, unset uses internal default.
      # @param metric_temporality [MetricTemporality] How frequently metrics should be exported.
      # @param durations_as_seconds [Boolean] Whether to use float seconds instead of integer milliseconds for
      #   durations.
      def initialize(
        url:,
        headers: nil,
        metric_periodicity: nil,
        metric_temporality: MetricTemporality::CUMULATIVE,
        durations_as_seconds: false
      )
        super
      end

      # @!visibility private
      def _to_bridge
        # @type self: OpenTelemetryMetricsOptions
        Internal::Bridge::Runtime::OpenTelemetryMetricsOptions.new(
          url:,
          headers:,
          metric_periodicity:,
          metric_temporality_delta: case metric_temporality
                                    when MetricTemporality::CUMULATIVE then false
                                    when MetricTemporality::DELTA then true
                                    else raise 'Unrecognized metric temporality'
                                    end,
          durations_as_seconds:
        )
      end
    end

    PrometheusMetricsOptions = Struct.new(
      :bind_address,
      :counters_total_suffix,
      :unit_suffix,
      :durations_as_seconds,
      keyword_init: true
    )

    # Options for exporting metrics to Prometheus.
    #
    # @!attribute bind_address
    #   @return [String] Address to bind to for Prometheus endpoint.
    # @!attribute counters_total_suffix
    #   @return [Boolean] If `true`, all counters will include a `_total` suffix.
    # @!attribute unit_suffix
    #   @return [Boolean] If `true`, all histograms will include the unit in their name as a suffix.
    # @!attribute durations_as_seconds
    #   @return [Boolean] Whether to use float seconds instead of integer milliseconds for durations.
    class PrometheusMetricsOptions
      # Create Prometheus options.
      #
      # @param bind_address [String] Address to bind to for Prometheus endpoint.
      # @param counters_total_suffix [Boolean] If `true`, all counters will include a `_total` suffix.
      # @param unit_suffix [Boolean] If `true`, all histograms will include the unit in their name as a suffix.
      # @param durations_as_seconds [Boolean] Whether to use float seconds instead of integer milliseconds for
      #   durations.
      def initialize(
        bind_address:,
        counters_total_suffix: false,
        unit_suffix: false,
        durations_as_seconds: false
      )
        super
      end

      # @!visibility private
      def _to_bridge
        # @type self: PrometheusMetricsOptions
        Internal::Bridge::Runtime::PrometheusMetricsOptions.new(
          bind_address:,
          counters_total_suffix:,
          unit_suffix:,
          durations_as_seconds:
        )
      end
    end

    # Default runtime, lazily created upon first access. If needing a different default, make sure it is updated via
    # {default=} before this is called (either directly or as a parameter to something like {Client}).
    #
    # @return [Runtime] Default runtime.
    def self.default
      @default ||= Runtime.new
    end

    # Set the default runtime. Must be called before {default} accessed.
    #
    # @param runtime [Runtime] Runtime to set as default.
    # @raise If default has already been accessed.
    def self.default=(runtime)
      raise 'Runtime already set or requested' unless @default.nil?

      @default = runtime
    end

    # @return [Metric::Meter] Metric meter that can create and record metric values.
    attr_reader :metric_meter

    # Create new Runtime. For most users, this should only be done once globally. In addition to creating a Rust thread
    # pool, this also consumes a Ruby thread for its lifetime.
    #
    # @param telemetry [TelemetryOptions] Telemetry options to set.
    def initialize(telemetry: TelemetryOptions.new)
      @core_runtime = Internal::Bridge::Runtime.new(
        Internal::Bridge::Runtime::Options.new(telemetry: telemetry._to_bridge)
      )
      @metric_meter = Internal::Metric::Meter.create_from_runtime(self) || Metric::Meter.null
      # We need a thread to run the command loop
      # TODO(cretz): Is this something users should be concerned about or need control over?
      Thread.new do
        @core_runtime.run_command_loop
      end
    end

    # @!visibility private
    def _core_runtime
      @core_runtime
    end
  end
end
