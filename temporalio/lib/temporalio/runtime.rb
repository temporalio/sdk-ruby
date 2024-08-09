# frozen_string_literal: true

require 'temporalio/internal/bridge/runtime'

module Temporalio
  # Runtime for Temporal Ruby SDK.
  #
  # Only one global {Runtime} needs to exist. Users are encouraged to use {default}. To configure it, create a runtime
  # before any clients are created, and set it via {default=}. Every time a new runtime is created, a new internal Rust
  # thread pool is created.
  class Runtime
    # Telemetry options for the runtime.
    #
    # @!attribute logging
    #   @return [LoggingOptions, nil] Logging options, default is new {LoggingOptions} with no parameters. Can be set
    #     to nil to disable logging.
    # @!attribute metrics
    #   @return [MetricsOptions, nil] Metrics options.
    TelemetryOptions = Struct.new(
      :logging,
      :metrics,
      keyword_init: true
    ) do
      # @!visibility private
      def initialize(*, **kwargs)
        kwargs[:logging] = LoggingOptions.new unless kwargs.key?(:logging)
        super
      end

      # @!visibility private
      def _to_bridge
        Internal::Bridge::Runtime::TelemetryOptions.new(
          logging: logging&._to_bridge,
          metrics: metrics&._to_bridge
        )
      end
    end

    # Logging options for runtime telemetry.
    #
    # @!attribute log_filter
    #   @return [LoggingFilterOptions, String] Logging filter for Core, default is new {LoggingFilterOptions} with no
    #     parameters.
    LoggingOptions = Struct.new(
      :log_filter,
      # TODO(cretz): forward_to
      keyword_init: true
    ) do
      # @!visibility private
      def initialize(*, **kwargs)
        kwargs[:log_filter] = LoggingFilterOptions.new unless kwargs.key?(:log_filter)
        super
      end

      # @!visibility private
      def _to_bridge
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

    # Logging filter options for Core.
    #
    # @!attribute core_level
    #   @return ['TRACE', 'DEBUG', 'INFO', 'WARN', 'ERROR'] Log level for Core log messages, default is +'WARN'+.
    # @!attribute other_level
    #   @return ['TRACE', 'DEBUG', 'INFO', 'WARN', 'ERROR'] Log level for other Rust log messages, default is +'WARN'+.
    LoggingFilterOptions = Struct.new(
      :core_level,
      :other_level,
      keyword_init: true
    ) do
      # @!visibility private
      def initialize(*, **kwargs)
        kwargs[:core_level] = 'WARN' unless kwargs.key?(:core_level)
        kwargs[:other_level] = 'ERROR' unless kwargs.key?(:other_level)
        super
      end

      # @!visibility private
      def _to_bridge
        "#{other_level},temporal_sdk_core=#{core_level},temporal_client=#{core_level},temporal_sdk=#{core_level}"
      end
    end

    # Metrics options for runtime telemetry. Either {opentelemetry} or {prometheus} required, but not both.
    #
    # @!attribute opentelemetry
    #   @return [OpenTelemetryMetricsOptions, nil] OpenTelemetry options if using OpenTelemetry. This is mutually
    #     exclusive with +prometheus+.
    # @!attribute prometheus
    #   @return [PrometheusMetricsOptions, nil] Prometheus options if using Prometheus. This is mutually exclusive with
    #     +opentelemetry+.
    # @!attribute attach_service_name
    #   @return [Boolean] Whether to put the service_name on every metric, default +true+.
    # @!attribute global_tags
    #   @return [Hash{String=>String}, nil] Resource tags to be applied to all metrics.
    # @!attribute metric_prefix
    #   @return [String, nil] Prefix to put on every Temporal metric. If unset, defaults to +temporal_+.
    MetricsOptions = Struct.new(
      :opentelemetry,
      :prometheus,
      :attach_service_name,
      :global_tags,
      :metric_prefix,
      keyword_init: true
    ) do
      # @!visibility private
      def initialize(*, **kwargs)
        kwargs[:attach_service_name] = true unless kwargs.key?(:attach_service_name)
        super
      end

      # @!visibility private
      def _to_bridge
        Internal::Bridge::Runtime::MetricsOptions.new(
          opentelemetry: opentelemetry&._to_bridge,
          prometheus: prometheus&._to_bridge,
          attach_service_name:,
          global_tags:,
          metric_prefix:
        )
      end
    end

    # Options for exporting metrics to OpenTelemetry.
    #
    # @!attribute url
    #   @return [String] URL for OpenTelemetry endpoint.
    # @!attribute headers
    #   @return [Hash{String=>String}, nil] Headers for OpenTelemetry endpoint.
    # @!attribute metric_periodicity_ms
    #   @return [Integer, nil] How frequently metrics should be exported, unset uses internal default.
    # @!attribute metric_temporality
    #   @return [MetricTemporality] How frequently metrics should be exported, default is
    #     {MetricTemporality::CUMULATIVE}.
    # @!attribute durations_as_seconds
    #   @return [Boolean] Whether to use float seconds instead of integer milliseconds for durations, default is
    #     +false+.
    OpenTelemetryMetricsOptions = Struct.new(
      :url,
      :headers,
      :metric_periodicity_ms,
      :metric_temporality,
      :durations_as_seconds,
      keyword_init: true
    ) do
      # OpenTelemetry metric temporality.
      module MetricTemporality # rubocop:disable Lint/ConstantDefinitionInBlock
        CUMULATIVE = 1
        DELTA = 2
      end

      # @!visibility private
      def initialize(*, **kwargs)
        kwargs[:metric_temporality] = MetricTemporality::CUMULATIVE unless kwargs.key?(:metric_temporality)
        kwargs[:durations_as_seconds] = false unless kwargs.key?(:durations_as_seconds)
        super
      end

      # @!visibility private
      def _to_bridge
        Internal::Bridge::Runtime::OpenTelemetryMetricsOptions.new(
          url:,
          headers:,
          metric_periodicity_ms:,
          metric_temporality_delta: case metric_temporality
                                    when MetricTemporality::CUMULATIVE then false
                                    when MetricTemporality::DELTA then true
                                    else raise 'Unrecognized metric temporality'
                                    end,
          durations_as_seconds:
        )
      end
    end

    # Options for exporting metrics to Prometheus.
    #
    # @!attribute bind_address
    #   @return [String] Address to bind to for Prometheus endpoint.
    # @!attribute counters_total_suffix
    #   @return [Boolean] If +true+, all counters will include a +_total+ suffix, default is +false+.
    # @!attribute unit_suffix
    #   @return [String] If +true+, all histograms will include the unit in their name as a suffix, default is +false+.
    # @!attribute durations_as_seconds
    #   @return [Boolean] Whether to use float seconds instead of integer milliseconds for durations, default is
    #     +false+.
    PrometheusOptions = Struct.new(
      :bind_address,
      :counters_total_suffix,
      :unit_suffix,
      :durations_as_seconds,
      keyword_init: true
    ) do
      # @!visibility private
      def initialize(*, **kwargs)
        kwargs[:counters_total_suffix] = false unless kwargs.key?(:counters_total_suffix)
        kwargs[:unit_suffix] = false unless kwargs.key?(:unit_suffix)
        kwargs[:durations_as_seconds] = false unless kwargs.key?(:durations_as_seconds)
        super
      end

      # @!visibility private
      def _to_bridge
        Internal::Bridge::Runtime::PrometheusOptions.new(
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

    # Create new Runtime. For most users, this should only be done once globally. In addition to creating a Rust thread
    # pool, this also consumes a Ruby thread for its lifetime.
    #
    # @param telemetry [TelemetryOptions] Telemetry options to set.
    def initialize(telemetry: TelemetryOptions.new)
      @core_runtime = Internal::Bridge::Runtime.new(
        Internal::Bridge::Runtime::Options.new(telemetry: telemetry._to_bridge)
      )
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
