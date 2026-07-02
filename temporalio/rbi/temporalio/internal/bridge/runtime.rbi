# typed: true

class Temporalio::Internal::Bridge::Runtime
  extend T::Sig

  sig { params(options: Temporalio::Internal::Bridge::Runtime::Options).returns(Temporalio::Internal::Bridge::Runtime) }
  def self.new(options); end

  sig { void }
  def run_command_loop; end

  sig { params(durations_as_seconds: T::Boolean).returns(T::Array[Temporalio::Runtime::MetricBuffer::Update]) }
  def retrieve_buffered_metrics(durations_as_seconds); end
end

class Temporalio::Internal::Bridge::Runtime::Options < ::Struct
  extend T::Sig

  sig do
    params(
      telemetry: Temporalio::Internal::Bridge::Runtime::TelemetryOptions,
      worker_heartbeat_interval: T.nilable(T.any(Integer, Float))
    ).void
  end
  def initialize(telemetry, worker_heartbeat_interval); end

  sig { returns(Temporalio::Internal::Bridge::Runtime::TelemetryOptions) }
  def telemetry; end

  sig { params(_: Temporalio::Internal::Bridge::Runtime::TelemetryOptions).void }
  def telemetry=(_); end

  sig { returns(T.nilable(T.any(Integer, Float))) }
  def worker_heartbeat_interval; end

  sig { params(_: T.nilable(T.any(Integer, Float))).void }
  def worker_heartbeat_interval=(_); end
end

class Temporalio::Internal::Bridge::Runtime::TelemetryOptions < ::Struct
  extend T::Sig

  sig do
    params(
      logging: T.nilable(Temporalio::Internal::Bridge::Runtime::LoggingOptions),
      metrics: T.nilable(Temporalio::Internal::Bridge::Runtime::MetricsOptions)
    ).void
  end
  def initialize(logging, metrics); end

  sig { returns(T.nilable(Temporalio::Internal::Bridge::Runtime::LoggingOptions)) }
  def logging; end

  sig { params(_: T.nilable(Temporalio::Internal::Bridge::Runtime::LoggingOptions)).void }
  def logging=(_); end

  sig { returns(T.nilable(Temporalio::Internal::Bridge::Runtime::MetricsOptions)) }
  def metrics; end

  sig { params(_: T.nilable(Temporalio::Internal::Bridge::Runtime::MetricsOptions)).void }
  def metrics=(_); end
end

class Temporalio::Internal::Bridge::Runtime::LoggingOptions < ::Struct
  extend T::Sig

  sig { params(log_filter: T.nilable(String)).void }
  def initialize(log_filter); end

  sig { returns(T.nilable(String)) }
  def log_filter; end

  sig { params(_: T.nilable(String)).void }
  def log_filter=(_); end
end

class Temporalio::Internal::Bridge::Runtime::MetricsOptions < ::Struct
  extend T::Sig

  sig do
    params(
      opentelemetry: T.nilable(Temporalio::Internal::Bridge::Runtime::OpenTelemetryMetricsOptions),
      prometheus: T.nilable(Temporalio::Internal::Bridge::Runtime::PrometheusMetricsOptions),
      buffered_with_size: T.nilable(Integer),
      attach_service_name: T::Boolean,
      global_tags: T.nilable(T::Hash[String, String]),
      metric_prefix: T.nilable(String)
    ).void
  end
  def initialize(opentelemetry, prometheus, buffered_with_size, attach_service_name, global_tags, metric_prefix); end

  sig { returns(T.nilable(Temporalio::Internal::Bridge::Runtime::OpenTelemetryMetricsOptions)) }
  def opentelemetry; end

  sig { params(_: T.nilable(Temporalio::Internal::Bridge::Runtime::OpenTelemetryMetricsOptions)).void }
  def opentelemetry=(_); end

  sig { returns(T.nilable(Temporalio::Internal::Bridge::Runtime::PrometheusMetricsOptions)) }
  def prometheus; end

  sig { params(_: T.nilable(Temporalio::Internal::Bridge::Runtime::PrometheusMetricsOptions)).void }
  def prometheus=(_); end

  sig { returns(T.nilable(Integer)) }
  def buffered_with_size; end

  sig { params(_: T.nilable(Integer)).void }
  def buffered_with_size=(_); end

  sig { returns(T::Boolean) }
  def attach_service_name; end

  sig { params(_: T::Boolean).void }
  def attach_service_name=(_); end

  sig { returns(T.nilable(T::Hash[String, String])) }
  def global_tags; end

  sig { params(_: T.nilable(T::Hash[String, String])).void }
  def global_tags=(_); end

  sig { returns(T.nilable(String)) }
  def metric_prefix; end

  sig { params(_: T.nilable(String)).void }
  def metric_prefix=(_); end
end

class Temporalio::Internal::Bridge::Runtime::OpenTelemetryMetricsOptions < ::Struct
  extend T::Sig

  sig do
    params(
      url: String,
      headers: T.nilable(T::Hash[String, String]),
      metric_periodicity: T.nilable(T.any(Integer, Float)),
      metric_temporality_delta: T::Boolean,
      durations_as_seconds: T::Boolean,
      http: T::Boolean,
      histogram_bucket_overrides: T.nilable(T::Hash[String, T::Array[Numeric]])
    ).void
  end
  def initialize(url, headers, metric_periodicity, metric_temporality_delta, durations_as_seconds, http, histogram_bucket_overrides); end

  sig { returns(String) }
  def url; end

  sig { params(_: String).void }
  def url=(_); end

  sig { returns(T.nilable(T::Hash[String, String])) }
  def headers; end

  sig { params(_: T.nilable(T::Hash[String, String])).void }
  def headers=(_); end

  sig { returns(T.nilable(T.any(Integer, Float))) }
  def metric_periodicity; end

  sig { params(_: T.nilable(T.any(Integer, Float))).void }
  def metric_periodicity=(_); end

  sig { returns(T::Boolean) }
  def metric_temporality_delta; end

  sig { params(_: T::Boolean).void }
  def metric_temporality_delta=(_); end

  sig { returns(T::Boolean) }
  def durations_as_seconds; end

  sig { params(_: T::Boolean).void }
  def durations_as_seconds=(_); end

  sig { returns(T::Boolean) }
  def http; end

  sig { params(_: T::Boolean).void }
  def http=(_); end

  sig { returns(T.nilable(T::Hash[String, T::Array[Numeric]])) }
  def histogram_bucket_overrides; end

  sig { params(_: T.nilable(T::Hash[String, T::Array[Numeric]])).void }
  def histogram_bucket_overrides=(_); end
end

class Temporalio::Internal::Bridge::Runtime::PrometheusMetricsOptions < ::Struct
  extend T::Sig

  sig do
    params(
      bind_address: String,
      counters_total_suffix: T::Boolean,
      unit_suffix: T::Boolean,
      durations_as_seconds: T::Boolean,
      histogram_bucket_overrides: T.nilable(T::Hash[String, T::Array[Numeric]])
    ).void
  end
  def initialize(bind_address, counters_total_suffix, unit_suffix, durations_as_seconds, histogram_bucket_overrides); end

  sig { returns(String) }
  def bind_address; end

  sig { params(_: String).void }
  def bind_address=(_); end

  sig { returns(T::Boolean) }
  def counters_total_suffix; end

  sig { params(_: T::Boolean).void }
  def counters_total_suffix=(_); end

  sig { returns(T::Boolean) }
  def unit_suffix; end

  sig { params(_: T::Boolean).void }
  def unit_suffix=(_); end

  sig { returns(T::Boolean) }
  def durations_as_seconds; end

  sig { params(_: T::Boolean).void }
  def durations_as_seconds=(_); end

  sig { returns(T.nilable(T::Hash[String, T::Array[Numeric]])) }
  def histogram_bucket_overrides; end

  sig { params(_: T.nilable(T::Hash[String, T::Array[Numeric]])).void }
  def histogram_bucket_overrides=(_); end
end
