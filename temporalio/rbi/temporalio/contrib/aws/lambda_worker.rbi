# typed: true

class Temporalio::Contrib::Aws::LambdaWorker
  extend T::Sig

  sig do
    params(
      version: Temporalio::WorkerDeploymentVersion,
      options: Temporalio::Contrib::Aws::LambdaWorker::Options,
      configure: T.nilable(T.proc.params(options: Temporalio::Contrib::Aws::LambdaWorker::Options, context: Object).returns(Temporalio::Contrib::Aws::LambdaWorker::Options))
    ).returns(Proc)
  end
  def self.define(version, options: Temporalio::Contrib::Aws::LambdaWorker::Options.new, &configure); end
end

class Temporalio::Contrib::Aws::LambdaWorker::Options < ::Data
  extend T::Sig

  sig do
    params(
      task_queue: T.nilable(String),
      activities: T::Array[T.any(Temporalio::Activity::Definition, T.class_of(Temporalio::Activity::Definition), Temporalio::Activity::Definition::Info)],
      workflows: T::Array[T.any(T.class_of(Temporalio::Workflow::Definition), Temporalio::Workflow::Definition::Info)],
      client_options: T::Hash[Symbol, Object],
      worker_options: T::Hash[Symbol, Object],
      default_versioning_behavior: Integer,
      shutdown_buffer: Numeric,
      shutdown_hooks: T::Array[T.proc.params(remaining: Float).void],
      plugins: T::Array[T.any(Temporalio::Client::Plugin, Temporalio::Worker::Plugin)]
    ).void
  end
  def initialize(task_queue: nil, activities: [], workflows: [], client_options: {}, worker_options: {}, default_versioning_behavior: Temporalio::VersioningBehavior::PINNED, shutdown_buffer: 7, shutdown_hooks: [], plugins: []); end

  sig { returns(T.nilable(String)) }
  def task_queue; end

  sig { returns(T::Array[T.any(Temporalio::Activity::Definition, T.class_of(Temporalio::Activity::Definition), Temporalio::Activity::Definition::Info)]) }
  def activities; end

  sig { returns(T::Array[T.any(T.class_of(Temporalio::Workflow::Definition), Temporalio::Workflow::Definition::Info)]) }
  def workflows; end

  sig { returns(T::Hash[Symbol, Object]) }
  def client_options; end

  sig { returns(T::Hash[Symbol, Object]) }
  def worker_options; end

  sig { returns(Integer) }
  def default_versioning_behavior; end

  sig { returns(Numeric) }
  def shutdown_buffer; end

  sig { returns(T::Array[T.proc.params(remaining: Float).void]) }
  def shutdown_hooks; end

  sig { returns(T::Array[T.any(Temporalio::Client::Plugin, Temporalio::Worker::Plugin)]) }
  def plugins; end

  sig { params(kwargs: T.untyped).returns(Temporalio::Contrib::Aws::LambdaWorker::Options) }
  def with(**kwargs); end
end
