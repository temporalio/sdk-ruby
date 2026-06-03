# typed: true

class Temporalio::Runtime
  extend T::Sig

  sig { returns(Temporalio::Metric::Meter) }
  attr_reader :metric_meter

  sig { params(telemetry: Temporalio::Runtime::TelemetryOptions, worker_heartbeat_interval: T.nilable(Float)).void }
  def initialize(telemetry: T.unsafe(nil), worker_heartbeat_interval: T.unsafe(nil)); end

  class << self
    extend T::Sig

    sig { returns(Temporalio::Runtime) }
    def default; end

    sig { params(runtime: Temporalio::Runtime).void }
    def default=(runtime); end
  end
end

class Temporalio::Runtime::TelemetryOptions < ::Data
  extend T::Sig

  sig { returns(T.nilable(Temporalio::Runtime::LoggingOptions)) }
  def logging; end

  sig { returns(T.nilable(Temporalio::Runtime::MetricsOptions)) }
  def metrics; end

  sig { params(logging: T.nilable(Temporalio::Runtime::LoggingOptions), metrics: T.nilable(Temporalio::Runtime::MetricsOptions)).void }
  def initialize(logging: T.unsafe(nil), metrics: T.unsafe(nil)); end
end

class Temporalio::Runtime::LoggingOptions < ::Data
  extend T::Sig

  sig { returns(T.any(Temporalio::Runtime::LoggingFilterOptions, String)) }
  def log_filter; end

  sig { params(log_filter: T.any(Temporalio::Runtime::LoggingFilterOptions, String)).void }
  def initialize(log_filter: T.unsafe(nil)); end
end

class Temporalio::Runtime::LoggingFilterOptions < ::Data
  extend T::Sig

  sig { returns(String) }
  def core_level; end

  sig { returns(String) }
  def other_level; end

  sig { params(core_level: String, other_level: String).void }
  def initialize(core_level: T.unsafe(nil), other_level: T.unsafe(nil)); end
end

class Temporalio::Runtime::MetricsOptions < ::Data
  extend T::Sig

  sig { returns(T.nilable(Temporalio::Runtime::OpenTelemetryMetricsOptions)) }
  def opentelemetry; end

  sig { returns(T.nilable(Temporalio::Runtime::PrometheusMetricsOptions)) }
  def prometheus; end

  sig { returns(T.nilable(Temporalio::Runtime::MetricBuffer)) }
  def buffer; end

  sig { returns(T::Boolean) }
  def attach_service_name; end

  sig { returns(T.nilable(T::Hash[String, String])) }
  def global_tags; end

  sig { returns(T.nilable(String)) }
  def metric_prefix; end

  sig do
    params(
      opentelemetry: T.nilable(Temporalio::Runtime::OpenTelemetryMetricsOptions),
      prometheus: T.nilable(Temporalio::Runtime::PrometheusMetricsOptions),
      buffer: T.nilable(Temporalio::Runtime::MetricBuffer),
      attach_service_name: T::Boolean,
      global_tags: T.nilable(T::Hash[String, String]),
      metric_prefix: T.nilable(String)
    ).void
  end
  def initialize(
    opentelemetry: T.unsafe(nil),
    prometheus: T.unsafe(nil),
    buffer: T.unsafe(nil),
    attach_service_name: T.unsafe(nil),
    global_tags: T.unsafe(nil),
    metric_prefix: T.unsafe(nil)
  ); end
end

class Temporalio::Runtime::OpenTelemetryMetricsOptions < ::Data
  extend T::Sig

  sig { returns(String) }
  def url; end

  sig { returns(T.nilable(T::Hash[String, String])) }
  def headers; end

  sig { returns(T.nilable(Numeric)) }
  def metric_periodicity; end

  sig { returns(Integer) }
  def metric_temporality; end

  sig { returns(T::Boolean) }
  def durations_as_seconds; end

  sig { returns(T::Boolean) }
  def http; end

  sig { returns(T.nilable(T::Hash[String, T::Array[Numeric]])) }
  def histogram_bucket_overrides; end

  sig do
    params(
      url: String,
      headers: T.nilable(T::Hash[String, String]),
      metric_periodicity: T.nilable(Float),
      metric_temporality: Integer,
      durations_as_seconds: T::Boolean,
      http: T::Boolean,
      histogram_bucket_overrides: T.nilable(T::Hash[String, T::Array[Numeric]])
    ).void
  end
  def initialize(
    url:,
    headers: T.unsafe(nil),
    metric_periodicity: T.unsafe(nil),
    metric_temporality: T.unsafe(nil),
    durations_as_seconds: T.unsafe(nil),
    http: T.unsafe(nil),
    histogram_bucket_overrides: T.unsafe(nil)
  ); end

  module MetricTemporality
    CUMULATIVE = T.let(T.unsafe(nil), Integer)
    DELTA = T.let(T.unsafe(nil), Integer)
  end
end

class Temporalio::Runtime::PrometheusMetricsOptions < ::Data
  extend T::Sig

  sig { returns(String) }
  def bind_address; end

  sig { returns(T::Boolean) }
  def counters_total_suffix; end

  sig { returns(T::Boolean) }
  def unit_suffix; end

  sig { returns(T::Boolean) }
  def durations_as_seconds; end

  sig { returns(T.nilable(T::Hash[String, T::Array[Numeric]])) }
  def histogram_bucket_overrides; end

  sig do
    params(
      bind_address: String,
      counters_total_suffix: T::Boolean,
      unit_suffix: T::Boolean,
      durations_as_seconds: T::Boolean,
      histogram_bucket_overrides: T.nilable(T::Hash[String, T::Array[Numeric]])
    ).void
  end
  def initialize(
    bind_address:,
    counters_total_suffix: T.unsafe(nil),
    unit_suffix: T.unsafe(nil),
    durations_as_seconds: T.unsafe(nil),
    histogram_bucket_overrides: T.unsafe(nil)
  ); end
end
