# typed: true

# Sorbet RBI types for the Temporal Ruby SDK.
# This file was split from rbi/temporalio.rbi by extra/split_rbi.rb.

class Temporalio::Worker::WorkflowReplayer
  extend T::Sig

  sig { returns(Temporalio::Worker::WorkflowReplayer::Options) }
  def options; end

  sig do
    params(
      workflows: T::Array[T.any(T.class_of(Temporalio::Workflow::Definition), Temporalio::Workflow::Definition::Info)],
      namespace: String,
      task_queue: String,
      data_converter: Temporalio::Converters::DataConverter,
      workflow_executor: Temporalio::Worker::WorkflowExecutor,
      plugins: T::Array[Temporalio::Worker::Plugin],
      interceptors: T::Array[Temporalio::Worker::Interceptor::Workflow],
      identity: T.nilable(String),
      logger: Logger,
      illegal_workflow_calls: T::Hash[String, T.any(Symbol, T::Array[Symbol])],
      workflow_failure_exception_types: T::Array[T.class_of(Exception)],
      workflow_payload_codec_thread_pool: T.nilable(Temporalio::Worker::ThreadPool),
      unsafe_workflow_io_enabled: T::Boolean,
      debug_mode: T::Boolean,
      runtime: Temporalio::Runtime,
      block: T.nilable(T.proc.params(worker: Temporalio::Worker::WorkflowReplayer::ReplayWorker).returns(T.untyped))
    ).void
  end
  def initialize(
    workflows:,
    namespace: T.unsafe(nil),
    task_queue: T.unsafe(nil),
    data_converter: T.unsafe(nil),
    workflow_executor: T.unsafe(nil),
    plugins: T.unsafe(nil),
    interceptors: T.unsafe(nil),
    identity: T.unsafe(nil),
    logger: T.unsafe(nil),
    illegal_workflow_calls: T.unsafe(nil),
    workflow_failure_exception_types: T.unsafe(nil),
    workflow_payload_codec_thread_pool: T.unsafe(nil),
    unsafe_workflow_io_enabled: T.unsafe(nil),
    debug_mode: T.unsafe(nil),
    runtime: T.unsafe(nil),
    &block
  ); end

  sig do
    params(
      history: Temporalio::WorkflowHistory,
      raise_on_replay_failure: T::Boolean
    ).returns(Temporalio::Worker::WorkflowReplayer::ReplayResult)
  end
  def replay_workflow(history, raise_on_replay_failure: T.unsafe(nil)); end

  sig do
    params(
      histories: T::Enumerable[Temporalio::WorkflowHistory],
      raise_on_replay_failure: T::Boolean
    ).returns(T::Array[Temporalio::Worker::WorkflowReplayer::ReplayResult])
  end
  def replay_workflows(histories, raise_on_replay_failure: T.unsafe(nil)); end

  sig do
    type_parameters(:T)
      .params(block: T.proc.params(worker: Temporalio::Worker::WorkflowReplayer::ReplayWorker).returns(T.type_parameter(:T)))
      .returns(T.type_parameter(:T))
  end
  def with_replay_worker(&block); end
end

class Temporalio::Worker::WorkflowReplayer::Options < ::Data
  extend T::Sig

  sig { returns(T::Array[T.any(T.class_of(Temporalio::Workflow::Definition), Temporalio::Workflow::Definition::Info)]) }
  def workflows; end

  sig { returns(String) }
  def namespace; end

  sig { returns(String) }
  def task_queue; end

  sig { returns(Temporalio::Converters::DataConverter) }
  def data_converter; end

  sig { returns(Temporalio::Worker::WorkflowExecutor) }
  def workflow_executor; end

  sig { returns(T::Array[Temporalio::Worker::Plugin]) }
  def plugins; end

  sig { returns(T::Array[Temporalio::Worker::Interceptor::Workflow]) }
  def interceptors; end

  sig { returns(T.nilable(String)) }
  def identity; end

  sig { returns(Logger) }
  def logger; end

  sig { returns(T::Hash[String, T.any(Symbol, T::Array[Symbol])]) }
  def illegal_workflow_calls; end

  sig { returns(T::Array[T.class_of(Exception)]) }
  def workflow_failure_exception_types; end

  sig { returns(T.nilable(Temporalio::Worker::ThreadPool)) }
  def workflow_payload_codec_thread_pool; end

  sig { returns(T::Boolean) }
  def unsafe_workflow_io_enabled; end

  sig { returns(T::Boolean) }
  def debug_mode; end

  sig { returns(Temporalio::Runtime) }
  def runtime; end

  sig { params(kwargs: T.untyped).returns(Temporalio::Worker::WorkflowReplayer::Options) }
  def with(**kwargs); end
end

class Temporalio::Worker::WorkflowReplayer::ReplayResult
  extend T::Sig

  sig { returns(Temporalio::WorkflowHistory) }
  def history; end

  sig { returns(T.nilable(Exception)) }
  def replay_failure; end

  sig { params(history: Temporalio::WorkflowHistory, replay_failure: T.nilable(Exception)).void }
  def initialize(history:, replay_failure:); end
end

class Temporalio::Worker::WorkflowReplayer::ReplayWorker
  extend T::Sig

  sig do
    params(
      history: Temporalio::WorkflowHistory,
      raise_on_replay_failure: T::Boolean
    ).returns(Temporalio::Worker::WorkflowReplayer::ReplayResult)
  end
  def replay_workflow(history, raise_on_replay_failure: T.unsafe(nil)); end
end
