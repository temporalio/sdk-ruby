# typed: true

class Temporalio::Activity::Context
  sig { returns(Temporalio::Activity::Context) }
  def self.current; end

  sig { returns(T.nilable(Temporalio::Activity::Context)) }
  def self.current_or_nil; end

  sig { returns(T::Boolean) }
  def self.exist?; end

  sig { returns(Temporalio::Activity::Info) }
  def info; end

  sig { returns(T.nilable(Temporalio::Activity::Definition)) }
  def instance; end

  sig { params(details: T.nilable(Object), detail_hints: T.nilable(T::Array[Object])).void }
  def heartbeat(*details, detail_hints: nil); end

  sig { returns(Temporalio::Cancellation) }
  def cancellation; end

  sig { returns(T.nilable(Temporalio::Activity::CancellationDetails)) }
  def cancellation_details; end

  sig { returns(Temporalio::Cancellation) }
  def worker_shutdown_cancellation; end

  sig { returns(Temporalio::Converters::PayloadConverter) }
  def payload_converter; end

  sig { returns(Temporalio::ScopedLogger) }
  def logger; end

  sig { returns(Temporalio::Metric::Meter) }
  def metric_meter; end

  sig { returns(Temporalio::Client) }
  def client; end
end
