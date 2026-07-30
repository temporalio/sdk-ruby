# typed: true

class Temporalio::Internal::Worker::ActivityWorker
  extend T::Sig

  LOG_TASKS = T.let(T.unsafe(nil), T::Boolean)

  sig { returns(Temporalio::Worker) }
  attr_reader :worker

  sig { returns(Temporalio::Internal::Bridge::Worker) }
  attr_reader :bridge_worker

  sig { params(worker: Temporalio::Worker, bridge_worker: Temporalio::Internal::Bridge::Worker).void }
  def initialize(worker:, bridge_worker:); end

  sig do
    params(
      task_token: String,
      activity: T.nilable(Temporalio::Internal::Worker::ActivityWorker::RunningActivity)
    ).void
  end
  def set_running_activity(task_token, activity); end

  sig { params(task_token: String).returns(T.nilable(Temporalio::Internal::Worker::ActivityWorker::RunningActivity)) }
  def get_running_activity(task_token); end

  sig { params(task_token: String).void }
  def remove_running_activity(task_token); end

  sig { void }
  def wait_all_complete; end

  sig { params(task: Object).void }
  def handle_task(task); end

  sig { params(task_token: String, start: Object).void }
  def handle_start_task(task_token, start); end

  sig { params(task_token: String, cancel: Object).void }
  def handle_cancel_task(task_token, cancel); end

  sig { params(task_token: String, defn: Temporalio::Activity::Definition::Info, start: Object).void }
  def execute_activity(task_token, defn, start); end

  sig do
    params(
      defn: Temporalio::Activity::Definition::Info,
      activity: Temporalio::Internal::Worker::ActivityWorker::RunningActivity,
      input: Temporalio::Worker::Interceptor::Activity::ExecuteInput
    ).void
  end
  def run_activity(defn, activity, input); end

  sig { params(activity: String).void }
  def assert_valid_activity(activity); end
end

class Temporalio::Internal::Worker::ActivityWorker::RunningActivity < Temporalio::Activity::Context
  extend T::Sig

  sig { returns(T::Boolean) }
  attr_reader :_server_requested_cancel

  sig { returns(T.nilable(Temporalio::Activity::Definition)) }
  attr_accessor :instance

  sig { returns(T.nilable(Temporalio::Worker::Interceptor::Activity::Outbound)) }
  attr_accessor :_outbound_impl

  sig do
    params(
      worker: Temporalio::Worker,
      info: Temporalio::Activity::Info,
      cancellation: Temporalio::Cancellation,
      worker_shutdown_cancellation: Temporalio::Cancellation,
      payload_converter: Temporalio::Converters::PayloadConverter,
      logger: Temporalio::ScopedLogger,
      runtime_metric_meter: Temporalio::Metric::Meter
    ).void
  end
  def initialize(
    worker:,
    info:,
    cancellation:,
    worker_shutdown_cancellation:,
    payload_converter:,
    logger:,
    runtime_metric_meter:
  ); end

  sig { params(reason: String, details: Temporalio::Activity::CancellationDetails).void }
  def _cancel(reason:, details:); end
end

class Temporalio::Internal::Worker::ActivityWorker::InboundImplementation < Temporalio::Worker::Interceptor::Activity::Inbound
  extend T::Sig

  sig { params(worker: Temporalio::Internal::Worker::ActivityWorker).void }
  def initialize(worker); end
end

class Temporalio::Internal::Worker::ActivityWorker::OutboundImplementation < Temporalio::Worker::Interceptor::Activity::Outbound
  extend T::Sig

  sig { params(worker: Temporalio::Internal::Worker::ActivityWorker, task_token: String).void }
  def initialize(worker, task_token); end
end
