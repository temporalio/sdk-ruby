# typed: true

module Temporalio::Contrib::Aws::LambdaWorker::OpenTelemetry; end

class Temporalio::Contrib::Aws::LambdaWorker::OpenTelemetry::Plugin < Temporalio::SimplePlugin
  extend T::Sig

  sig { returns(Temporalio::Contrib::Aws::LambdaWorker::OpenTelemetry::Plugin::Options) }
  attr_reader :otel_options

  sig { returns(Temporalio::Runtime) }
  attr_reader :runtime

  sig do
    params(
      tracer: T.nilable(Object),
      tracer_provider: T.nilable(Object),
      endpoint: T.nilable(String),
      service_name: T.nilable(String),
      metric_periodicity: T.nilable(Numeric)
    ).void
  end
  def initialize(
    tracer: T.unsafe(nil),
    tracer_provider: T.unsafe(nil),
    endpoint: T.unsafe(nil),
    service_name: T.unsafe(nil),
    metric_periodicity: T.unsafe(nil)
  ); end

  sig do
    params(
      options: Temporalio::Client::Connection::Options,
      next_call: T.proc.params(arg0: Temporalio::Client::Connection::Options).returns(Temporalio::Client::Connection)
    ).returns(Temporalio::Client::Connection)
  end
  def connect_client(options, next_call); end

  sig { returns(T.proc.void) }
  def lambda_shutdown_hook; end

end

class Temporalio::Contrib::Aws::LambdaWorker::OpenTelemetry::Plugin::Options < ::Data
  extend T::Sig

  sig { returns(Object) }
  def tracer; end

  sig { returns(Object) }
  def tracer_provider; end

  sig { returns(String) }
  def endpoint; end

  sig { returns(T.nilable(String)) }
  def service_name; end

  sig { returns(T.nilable(Float)) }
  def metric_periodicity; end

  sig do
    params(
      tracer: Object,
      tracer_provider: Object,
      endpoint: String,
      service_name: T.nilable(String),
      metric_periodicity: T.nilable(Float)
    ).void
  end
  def initialize(tracer:, tracer_provider:, endpoint:, service_name:, metric_periodicity:); end
end
