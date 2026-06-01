# typed: true

# Sorbet RBI types for the Temporal Ruby SDK.
# This file was split from rbi/temporalio.rbi by extra/split_rbi.rb.

class Temporalio::SimplePlugin
  include Temporalio::Client::Plugin
  include Temporalio::Worker::Plugin

  extend T::Sig

  sig { returns(Temporalio::SimplePlugin::Options) }
  def options; end

  sig do
    params(
      name: String,
      data_converter: T.nilable(T.any(Temporalio::Converters::DataConverter, T.proc.params(arg0: Temporalio::Converters::DataConverter).returns(Temporalio::Converters::DataConverter))),
      client_interceptors: T.nilable(T.any(T::Array[Temporalio::Client::Interceptor], T.proc.params(arg0: T::Array[Temporalio::Client::Interceptor]).returns(T::Array[Temporalio::Client::Interceptor]))),
      activities: T.nilable(T.any(T::Array[T.any(Temporalio::Activity::Definition, T.class_of(Temporalio::Activity::Definition), Temporalio::Activity::Definition::Info)], T.proc.params(arg0: T::Array[T.any(Temporalio::Activity::Definition, T.class_of(Temporalio::Activity::Definition), Temporalio::Activity::Definition::Info)]).returns(T::Array[T.any(Temporalio::Activity::Definition, T.class_of(Temporalio::Activity::Definition), Temporalio::Activity::Definition::Info)]))),
      workflows: T.nilable(T.any(T::Array[T.any(T.class_of(Temporalio::Workflow::Definition), Temporalio::Workflow::Definition::Info)], T.proc.params(arg0: T::Array[T.any(T.class_of(Temporalio::Workflow::Definition), Temporalio::Workflow::Definition::Info)]).returns(T::Array[T.any(T.class_of(Temporalio::Workflow::Definition), Temporalio::Workflow::Definition::Info)]))),
      worker_interceptors: T.nilable(T.any(T::Array[T.any(Temporalio::Worker::Interceptor::Activity, Temporalio::Worker::Interceptor::Workflow)], T.proc.params(arg0: T::Array[T.any(Temporalio::Worker::Interceptor::Activity, Temporalio::Worker::Interceptor::Workflow)]).returns(T::Array[T.any(Temporalio::Worker::Interceptor::Activity, Temporalio::Worker::Interceptor::Workflow)]))),
      workflow_failure_exception_types: T.nilable(T.any(T::Array[String], T.proc.params(arg0: T::Array[String]).returns(T::Array[String]))),
      run_context: T.nilable(T.proc.params(arg0: T.any(Temporalio::Worker::Plugin::RunWorkerOptions, Temporalio::Worker::Plugin::WithWorkflowReplayWorkerOptions), arg1: T.proc.params(arg0: T.any(Temporalio::Worker::Plugin::RunWorkerOptions, Temporalio::Worker::Plugin::WithWorkflowReplayWorkerOptions)).returns(T.untyped)).returns(T.untyped))
    ).void
  end
  def initialize(
    name:,
    data_converter: T.unsafe(nil),
    client_interceptors: T.unsafe(nil),
    activities: T.unsafe(nil),
    workflows: T.unsafe(nil),
    worker_interceptors: T.unsafe(nil),
    workflow_failure_exception_types: T.unsafe(nil),
    run_context: T.unsafe(nil)
  ); end
end

class Temporalio::SimplePlugin::Options
  extend T::Sig

  sig { returns(String) }
  def name; end
end
