# typed: true

# Sorbet RBI types for the Temporal Ruby SDK.
# This file was split from rbi/temporalio.rbi by extra/split_rbi.rb.

class Temporalio::Worker
  extend T::Sig

  sig { returns(Options) }
  def options; end

  sig do
    params(
      client: Temporalio::Client,
      task_queue: String,
      activities: T::Array[T.any(Temporalio::Activity::Definition, T.class_of(Temporalio::Activity::Definition), Temporalio::Activity::Definition::Info)],
      workflows: T::Array[T.any(T.class_of(Temporalio::Workflow::Definition), Temporalio::Workflow::Definition::Info)],
      tuner: Temporalio::Worker::Tuner,
      activity_executors: T::Hash[Symbol, Temporalio::Worker::ActivityExecutor],
      workflow_executor: Temporalio::Worker::WorkflowExecutor,
      plugins: T::Array[Temporalio::Worker::Plugin],
      interceptors: T::Array[T.any(Temporalio::Worker::Interceptor::Activity, Temporalio::Worker::Interceptor::Workflow)],
      identity: T.nilable(String),
      logger: Logger,
      max_cached_workflows: Integer,
      max_concurrent_workflow_task_polls: Integer,
      nonsticky_to_sticky_poll_ratio: Numeric,
      max_concurrent_activity_task_polls: Integer,
      no_remote_activities: T::Boolean,
      sticky_queue_schedule_to_start_timeout: Numeric,
      max_heartbeat_throttle_interval: Numeric,
      default_heartbeat_throttle_interval: Numeric,
      max_activities_per_second: T.nilable(Numeric),
      max_task_queue_activities_per_second: T.nilable(Numeric),
      graceful_shutdown_period: Numeric,
      disable_eager_activity_execution: T::Boolean,
      illegal_workflow_calls: T::Hash[String, T.any(Symbol, T::Array[T.any(Symbol, Temporalio::Worker::IllegalWorkflowCallValidator)], Temporalio::Worker::IllegalWorkflowCallValidator)],
      workflow_failure_exception_types: T::Array[T.class_of(Exception)],
      workflow_payload_codec_thread_pool: T.nilable(Temporalio::Worker::ThreadPool),
      unsafe_workflow_io_enabled: T::Boolean,
      deployment_options: Temporalio::Worker::DeploymentOptions,
      workflow_task_poller_behavior: Temporalio::Worker::PollerBehavior,
      activity_task_poller_behavior: Temporalio::Worker::PollerBehavior,
      debug_mode: T::Boolean
    ).void
  end
  def initialize(
    client:,
    task_queue:,
    activities: T.unsafe(nil),
    workflows: T.unsafe(nil),
    tuner: T.unsafe(nil),
    activity_executors: T.unsafe(nil),
    workflow_executor: T.unsafe(nil),
    plugins: T.unsafe(nil),
    interceptors: T.unsafe(nil),
    identity: T.unsafe(nil),
    logger: T.unsafe(nil),
    max_cached_workflows: T.unsafe(nil),
    max_concurrent_workflow_task_polls: T.unsafe(nil),
    nonsticky_to_sticky_poll_ratio: T.unsafe(nil),
    max_concurrent_activity_task_polls: T.unsafe(nil),
    no_remote_activities: T.unsafe(nil),
    sticky_queue_schedule_to_start_timeout: T.unsafe(nil),
    max_heartbeat_throttle_interval: T.unsafe(nil),
    default_heartbeat_throttle_interval: T.unsafe(nil),
    max_activities_per_second: T.unsafe(nil),
    max_task_queue_activities_per_second: T.unsafe(nil),
    graceful_shutdown_period: T.unsafe(nil),
    disable_eager_activity_execution: T.unsafe(nil),
    illegal_workflow_calls: T.unsafe(nil),
    workflow_failure_exception_types: T.unsafe(nil),
    workflow_payload_codec_thread_pool: T.unsafe(nil),
    unsafe_workflow_io_enabled: T.unsafe(nil),
    deployment_options: T.unsafe(nil),
    workflow_task_poller_behavior: T.unsafe(nil),
    activity_task_poller_behavior: T.unsafe(nil),
    debug_mode: T.unsafe(nil)
  ); end

  sig { returns(String) }
  def task_queue; end

  sig { returns(Temporalio::Client) }
  def client; end

  sig { params(new_client: Temporalio::Client).void }
  def client=(new_client); end

  sig do
    type_parameters(:T)
      .params(
        cancellation: Temporalio::Cancellation,
        shutdown_signals: T::Array[T.any(String, Integer)],
        raise_in_block_on_shutdown: T.nilable(Exception),
        wait_block_complete: T::Boolean,
        block: T.nilable(T.proc.returns(T.type_parameter(:T)))
      ).returns(T.type_parameter(:T))
  end
  def run(
    cancellation: T.unsafe(nil),
    shutdown_signals: T.unsafe(nil),
    raise_in_block_on_shutdown: T.unsafe(nil),
    wait_block_complete: T.unsafe(nil),
    &block
  ); end

  class << self
    extend T::Sig

    sig { returns(String) }
    def default_build_id; end

    sig { returns(Temporalio::Worker::DeploymentOptions) }
    def default_deployment_options; end

    sig do
      type_parameters(:T)
        .params(
          workers: Temporalio::Worker,
          cancellation: Temporalio::Cancellation,
          shutdown_signals: T::Array[T.any(String, Integer)],
          raise_in_block_on_shutdown: T.nilable(Exception),
          wait_block_complete: T::Boolean,
          block: T.nilable(T.proc.returns(T.type_parameter(:T)))
        ).returns(T.type_parameter(:T))
    end
    def run_all(
      *workers,
      cancellation: T.unsafe(nil),
      shutdown_signals: T.unsafe(nil),
      raise_in_block_on_shutdown: T.unsafe(nil),
      wait_block_complete: T.unsafe(nil),
      &block
    ); end

    sig { returns(T::Hash[String, T.any(Symbol, T::Array[T.any(Symbol, IllegalWorkflowCallValidator)], IllegalWorkflowCallValidator)]) }
    def default_illegal_workflow_calls; end
  end
end

class Temporalio::Worker::Options < ::Data
  extend T::Sig

  sig { returns(Temporalio::Client) }
  def client; end

  sig { returns(String) }
  def task_queue; end

  sig { returns(T::Array[T.any(Temporalio::Activity::Definition, T.class_of(Temporalio::Activity::Definition), Temporalio::Activity::Definition::Info)]) }
  def activities; end

  sig { returns(T::Array[T.any(T.class_of(Temporalio::Workflow::Definition), Temporalio::Workflow::Definition::Info)]) }
  def workflows; end

  sig { returns(Temporalio::Worker::Tuner) }
  def tuner; end

  sig { returns(T::Hash[Symbol, Temporalio::Worker::ActivityExecutor]) }
  def activity_executors; end

  sig { returns(Temporalio::Worker::WorkflowExecutor) }
  def workflow_executor; end

  sig { returns(T::Array[Temporalio::Worker::Plugin]) }
  def plugins; end

  sig { returns(T::Array[T.any(Temporalio::Worker::Interceptor::Activity, Temporalio::Worker::Interceptor::Workflow)]) }
  def interceptors; end

  sig { returns(T.nilable(String)) }
  def identity; end

  sig { returns(Logger) }
  def logger; end

  sig { returns(Integer) }
  def max_cached_workflows; end

  sig { returns(Integer) }
  def max_concurrent_workflow_task_polls; end

  sig { returns(Numeric) }
  def nonsticky_to_sticky_poll_ratio; end

  sig { returns(Integer) }
  def max_concurrent_activity_task_polls; end

  sig { returns(T::Boolean) }
  def no_remote_activities; end

  sig { returns(Numeric) }
  def sticky_queue_schedule_to_start_timeout; end

  sig { returns(Numeric) }
  def max_heartbeat_throttle_interval; end

  sig { returns(Numeric) }
  def default_heartbeat_throttle_interval; end

  sig { returns(T.nilable(Numeric)) }
  def max_activities_per_second; end

  sig { returns(T.nilable(Numeric)) }
  def max_task_queue_activities_per_second; end

  sig { returns(Numeric) }
  def graceful_shutdown_period; end

  sig { returns(T::Boolean) }
  def disable_eager_activity_execution; end

  sig { returns(T::Hash[String, T.any(Symbol, T::Array[T.any(Symbol, Temporalio::Worker::IllegalWorkflowCallValidator)], Temporalio::Worker::IllegalWorkflowCallValidator)]) }
  def illegal_workflow_calls; end

  sig { returns(T::Array[T.class_of(Exception)]) }
  def workflow_failure_exception_types; end

  sig { returns(T.nilable(Temporalio::Worker::ThreadPool)) }
  def workflow_payload_codec_thread_pool; end

  sig { returns(T::Boolean) }
  def unsafe_workflow_io_enabled; end

  sig { returns(Temporalio::Worker::PollerBehavior) }
  def workflow_task_poller_behavior; end

  sig { returns(Temporalio::Worker::PollerBehavior) }
  def activity_task_poller_behavior; end

  sig { returns(Temporalio::Worker::DeploymentOptions) }
  def deployment_options; end

  sig { returns(T::Boolean) }
  def debug_mode; end

  sig { params(kwargs: T.untyped).returns(Temporalio::Worker::Options) }
  def with(**kwargs); end
end
