# typed: true

class Temporalio::Client::ActivityExecutionOptions
  class << self
    sig do
      params(options: Temporalio::Api::Activity::V1::ActivityOptions)
        .returns(Temporalio::Client::ActivityExecutionOptions)
    end
    def _from_proto(options); end
  end

  sig do
    params(
      task_queue: T.nilable(String),
      schedule_to_close_timeout: T.nilable(Float),
      schedule_to_start_timeout: T.nilable(Float),
      start_to_close_timeout: T.nilable(Float),
      heartbeat_timeout: T.nilable(Float),
      retry_policy: T.nilable(Temporalio::RetryPolicy),
      priority: Temporalio::Priority,
      start_delay: T.nilable(Float)
    ).void
  end
  def initialize(
    task_queue:,
    schedule_to_close_timeout:,
    schedule_to_start_timeout:,
    start_to_close_timeout:,
    heartbeat_timeout:,
    retry_policy:,
    priority:,
    start_delay:
  ); end

  sig { returns(T.nilable(String)) }
  attr_reader :task_queue

  sig { returns(T.nilable(Float)) }
  attr_reader :schedule_to_close_timeout

  sig { returns(T.nilable(Float)) }
  attr_reader :schedule_to_start_timeout

  sig { returns(T.nilable(Float)) }
  attr_reader :start_to_close_timeout

  sig { returns(T.nilable(Float)) }
  attr_reader :heartbeat_timeout

  sig { returns(T.nilable(Temporalio::RetryPolicy)) }
  attr_reader :retry_policy

  sig { returns(Temporalio::Priority) }
  attr_reader :priority

  sig { returns(T.nilable(Float)) }
  attr_reader :start_delay
end
