# typed: true

class Temporalio::Activity::Info < ::Data
  sig do
    params(
      activity_id: String,
      activity_type: String,
      attempt: Integer,
      current_attempt_scheduled_time: Time,
      heartbeat_timeout: T.nilable(Float),
      local: T::Boolean,
      priority: T.nilable(Temporalio::Priority),
      raw_heartbeat_details: T::Array[Temporalio::Converters::RawValue],
      retry_policy: T.nilable(Temporalio::RetryPolicy),
      schedule_to_close_timeout: T.nilable(Float),
      scheduled_time: Time,
      start_to_close_timeout: T.nilable(Float),
      started_time: Time,
      task_queue: String,
      task_token: String,
      workflow_id: String,
      workflow_namespace: String,
      workflow_run_id: String,
      workflow_type: String
    ).void
  end
  def initialize(activity_id:, activity_type:, attempt:, current_attempt_scheduled_time:, heartbeat_timeout:, local:, priority:, raw_heartbeat_details:, retry_policy:, schedule_to_close_timeout:, scheduled_time:, start_to_close_timeout:, started_time:, task_queue:, task_token:, workflow_id:, workflow_namespace:, workflow_run_id:, workflow_type:); end

  sig { returns(String) }
  def activity_id; end

  sig { returns(String) }
  def activity_type; end

  sig { returns(Integer) }
  def attempt; end

  sig { returns(Time) }
  def current_attempt_scheduled_time; end

  sig { params(hints: T.nilable(T::Array[Object])).returns(T::Array[T.nilable(Object)]) }
  def heartbeat_details(hints: nil); end

  sig { returns(T.nilable(Numeric)) }
  def heartbeat_timeout; end

  sig { returns(T::Boolean) }
  def local?; end

  sig { returns(Temporalio::Priority) }
  def priority; end

  sig { returns(T::Array[Temporalio::Converters::RawValue]) }
  def raw_heartbeat_details; end

  sig { returns(T.nilable(Temporalio::RetryPolicy)) }
  def retry_policy; end

  sig { returns(T.nilable(Numeric)) }
  def schedule_to_close_timeout; end

  sig { returns(Time) }
  def scheduled_time; end

  sig { returns(T.nilable(Numeric)) }
  def start_to_close_timeout; end

  sig { returns(Time) }
  def started_time; end

  sig { returns(String) }
  def task_queue; end

  sig { returns(String) }
  def task_token; end

  sig { returns(String) }
  def workflow_id; end

  sig { returns(String) }
  def workflow_namespace; end

  sig { returns(String) }
  def workflow_run_id; end

  sig { returns(String) }
  def workflow_type; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Activity::Info) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end

    sig { params(args: T.untyped).returns(Temporalio::Activity::Info) }
    def new(*args); end
  end
end
