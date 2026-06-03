# typed: true

class Temporalio::Testing::ActivityEnvironment
  extend T::Sig

  sig { returns(Temporalio::Activity::Info) }
  def self.default_info; end

  sig do
    params(
      info: Temporalio::Activity::Info,
      on_heartbeat: T.nilable(Proc),
      cancellation: Temporalio::Cancellation,
      on_cancellation_details: T.nilable(Proc),
      worker_shutdown_cancellation: Temporalio::Cancellation,
      payload_converter: Temporalio::Converters::PayloadConverter,
      logger: Logger,
      activity_executors: T::Hash[Symbol, Temporalio::Worker::ActivityExecutor],
      metric_meter: T.nilable(Temporalio::Metric::Meter),
      client: T.nilable(Temporalio::Client)
    ).void
  end
  def initialize(
    info: T.unsafe(nil),
    on_heartbeat: T.unsafe(nil),
    cancellation: T.unsafe(nil),
    on_cancellation_details: T.unsafe(nil),
    worker_shutdown_cancellation: T.unsafe(nil),
    payload_converter: T.unsafe(nil),
    logger: T.unsafe(nil),
    activity_executors: T.unsafe(nil),
    metric_meter: T.unsafe(nil),
    client: T.unsafe(nil)
  ); end

  sig do
    params(
      activity: T.any(Temporalio::Activity::Definition, T.class_of(Temporalio::Activity::Definition), Temporalio::Activity::Definition::Info),
      args: T.nilable(Object)
    ).returns(T.anything)
  end
  def run(activity, *args); end
end
