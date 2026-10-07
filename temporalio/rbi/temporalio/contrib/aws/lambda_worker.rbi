# typed: true

module Temporalio::Contrib; end

module Temporalio::Contrib::Aws; end

class Temporalio::Contrib::Aws::LambdaWorker
  extend T::Sig

  DEFAULT_ACTIVITY_SLOTS = T.let(T.unsafe(nil), Integer)
  DEFAULT_LOCAL_ACTIVITY_SLOTS = T.let(T.unsafe(nil), Integer)
  DEFAULT_WORKFLOW_SLOTS = T.let(T.unsafe(nil), Integer)
  DEFAULT_MAX_CACHED_WORKFLOWS = T.let(T.unsafe(nil), Integer)
  DEFAULT_GRACEFUL_SHUTDOWN_PERIOD = T.let(T.unsafe(nil), Integer)
  DEFAULT_SHUTDOWN_BUFFER = T.let(T.unsafe(nil), Integer)
  DEFAULT_WORKER_OPTIONS = T.let(T.unsafe(nil), T::Hash[Symbol, Object])
  DEFAULT_LOGGER = T.let(T.unsafe(nil), Logger)

  sig do
    params(
      version: Temporalio::WorkerDeploymentVersion,
      options: Temporalio::Contrib::Aws::LambdaWorker::Options
    ).returns(T.proc.params(arg0: Object, arg1: Object).void)
  end
  def self.define(version, options:); end
end

class Temporalio::Contrib::Aws::LambdaWorker::Options < ::Data
  extend T::Sig

  sig { returns(T.nilable(String)) }
  def task_queue; end

  sig do
    returns(
      T::Array[
        T.any(
          Temporalio::Activity::Definition,
          T.class_of(Temporalio::Activity::Definition),
          Temporalio::Activity::Definition::Info
        )
      ]
    )
  end
  def activities; end

  sig { returns(T::Array[T.any(T.class_of(Temporalio::Workflow::Definition), Temporalio::Workflow::Definition::Info)]) }
  def workflows; end

  sig { returns(T::Hash[Symbol, Object]) }
  def client_options; end

  sig { returns(T::Hash[Symbol, Object]) }
  def client_connect_options; end

  sig { returns(T::Hash[Symbol, Object]) }
  def worker_options; end

  sig { returns(Integer) }
  def default_versioning_behavior; end

  sig { returns(Numeric) }
  def shutdown_buffer; end

  sig { returns(T::Array[T.proc.void]) }
  def shutdown_hooks; end

  sig { returns(T::Array[T.any(Temporalio::Client::Plugin, Temporalio::Worker::Plugin)]) }
  def plugins; end

  sig do
    params(
      task_queue: T.nilable(String),
      activities: T::Array[
        T.any(
          Temporalio::Activity::Definition,
          T.class_of(Temporalio::Activity::Definition),
          Temporalio::Activity::Definition::Info
        )
      ],
      workflows: T::Array[T.any(T.class_of(Temporalio::Workflow::Definition), Temporalio::Workflow::Definition::Info)],
      client_options: T.nilable(T::Hash[Symbol, Object]),
      client_connect_options: T.nilable(T::Hash[Symbol, Object]),
      worker_options: T::Hash[Symbol, Object],
      default_versioning_behavior: Integer,
      shutdown_buffer: Numeric,
      shutdown_hooks: T::Array[T.proc.void],
      plugins: T::Array[T.any(Temporalio::Client::Plugin, Temporalio::Worker::Plugin)]
    ).void
  end
  def initialize(
    task_queue: T.unsafe(nil),
    activities: T.unsafe(nil),
    workflows: T.unsafe(nil),
    client_options: T.unsafe(nil),
    client_connect_options: T.unsafe(nil),
    worker_options: T.unsafe(nil),
    default_versioning_behavior: T.unsafe(nil),
    shutdown_buffer: T.unsafe(nil),
    shutdown_hooks: T.unsafe(nil),
    plugins: T.unsafe(nil)
  ); end

  sig { params(kwargs: T::Hash[Symbol, Object]).returns(Temporalio::Contrib::Aws::LambdaWorker::Options) }
  def with(**kwargs); end
end

class Temporalio::Contrib::Aws::LambdaWorker::Definition < ::Data
  extend T::Sig

  sig { returns(Temporalio::WorkerDeploymentVersion) }
  def version; end

  sig { returns(Temporalio::Contrib::Aws::LambdaWorker::Options) }
  def options; end

  sig { returns(T::Array[String]) }
  def client_connect_args; end

  sig { returns(T::Hash[Symbol, Object]) }
  def client_connect_options; end

  sig { returns(T::Array[Temporalio::Client::Plugin]) }
  def client_plugins; end

  sig { returns(T::Array[Temporalio::Worker::Plugin]) }
  def worker_plugins; end

  sig { returns(Temporalio::Worker::DeploymentOptions) }
  def deployment_options; end

  sig { returns(Logger) }
  def logger; end

  sig do
    params(
      version: Temporalio::WorkerDeploymentVersion,
      options: Temporalio::Contrib::Aws::LambdaWorker::Options,
      client_connect_args: T::Array[String],
      client_connect_options: T::Hash[Symbol, Object],
      client_plugins: T::Array[Temporalio::Client::Plugin],
      worker_plugins: T::Array[Temporalio::Worker::Plugin],
      deployment_options: Temporalio::Worker::DeploymentOptions,
      logger: Logger
    ).void
  end
  def initialize(
    version:,
    options:,
    client_connect_args:,
    client_connect_options:,
    client_plugins:,
    worker_plugins:,
    deployment_options:,
    logger:
  ); end
end
