# typed: true

class Temporalio::Client::ActivityExecution
  sig do
    params(
      raw_info: T.any(
        Temporalio::Api::Activity::V1::ActivityExecutionListInfo,
        Temporalio::Api::Activity::V1::ActivityExecutionInfo
      )
    ).void
  end
  def initialize(raw_info); end

  sig do
    returns(
      T.any(
        Temporalio::Api::Activity::V1::ActivityExecutionListInfo,
        Temporalio::Api::Activity::V1::ActivityExecutionInfo
      )
    )
  end
  attr_reader :raw_info

  sig { returns(String) }
  def activity_id; end

  sig { returns(T.nilable(String)) }
  def activity_run_id; end

  sig { returns(String) }
  def activity_type; end

  sig { returns(T.nilable(Time)) }
  def schedule_time; end

  sig { returns(T.nilable(Time)) }
  def close_time; end

  sig { returns(Integer) }
  def status; end

  sig { returns(T.nilable(Temporalio::SearchAttributes)) }
  def search_attributes; end

  sig { returns(String) }
  def task_queue; end

  sig { returns(T.nilable(Float)) }
  def execution_duration; end
end

class Temporalio::Client::ActivityExecution::Description < ::Temporalio::Client::ActivityExecution
  sig do
    params(
      raw_description: Temporalio::Api::WorkflowService::V1::DescribeActivityExecutionResponse,
      data_converter: Temporalio::Converters::DataConverter
    ).void
  end
  def initialize(raw_description, data_converter); end

  sig { returns(Temporalio::Api::WorkflowService::V1::DescribeActivityExecutionResponse) }
  attr_reader :raw_description

  sig { returns(T.nilable(Integer)) }
  def run_state; end

  sig { returns(T.nilable(Float)) }
  def schedule_to_close_timeout; end

  sig { returns(T.nilable(Float)) }
  def schedule_to_start_timeout; end

  sig { returns(T.nilable(Float)) }
  def start_to_close_timeout; end

  sig { returns(T.nilable(Float)) }
  def heartbeat_timeout; end

  sig { returns(T::Boolean) }
  def has_heartbeat_details?; end

  sig { params(hints: T.nilable(T::Array[Object])).returns(T::Array[T.nilable(Object)]) }
  def heartbeat_details(hints: T.unsafe(nil)); end

  sig { returns(Temporalio::RetryPolicy) }
  def retry_policy; end

  sig { returns(T.nilable(Time)) }
  def last_heartbeat_time; end

  sig { returns(T.nilable(Time)) }
  def last_started_time; end

  sig { returns(Integer) }
  def attempt; end

  sig { returns(T.nilable(Temporalio::Error::Failure)) }
  def last_failure; end

  sig { returns(T.nilable(Time)) }
  def expiration_time; end

  sig { returns(T.nilable(String)) }
  def last_worker_identity; end

  sig { returns(T.nilable(Float)) }
  def current_retry_interval; end

  sig { returns(T.nilable(Time)) }
  def last_attempt_complete_time; end

  sig { returns(T.nilable(Time)) }
  def next_attempt_schedule_time; end

  sig { returns(T.nilable(Temporalio::WorkerDeploymentVersion)) }
  def last_deployment_version; end

  sig { returns(Temporalio::Priority) }
  def priority; end

  sig { returns(T.nilable(String)) }
  def canceled_reason; end

  sig { returns(T.nilable(String)) }
  def static_summary; end

  sig { returns(T.nilable(String)) }
  def static_details; end

  private

  sig { returns([T.nilable(String), T.nilable(String)]) }
  def user_metadata; end
end
