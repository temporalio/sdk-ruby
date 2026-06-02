# typed: true

# Sorbet RBI types for the Temporal Ruby SDK.
# This file was split from rbi/temporalio.rbi by extra/split_rbi.rb.

module Temporalio::Contrib; end

module Temporalio::Contrib::OpenTelemetry; end

class Temporalio::Contrib::OpenTelemetry::TracingInterceptor
  include Temporalio::Client::Interceptor
  include Temporalio::Worker::Interceptor::Activity
  include Temporalio::Worker::Interceptor::Workflow

  extend T::Sig

  sig { returns(T.anything) }
  attr_reader :tracer

  sig do
    params(
      tracer: T.anything,
      header_key: String,
      propagator: T.anything,
      always_create_workflow_spans: T::Boolean
    ).void
  end
  def initialize(tracer, header_key: T.unsafe(nil), propagator: T.unsafe(nil), always_create_workflow_spans: T.unsafe(nil)); end
end

module Temporalio::Contrib::OpenTelemetry::Workflow
  class << self
    extend T::Sig

    sig do
      type_parameters(:T)
        .params(
          name: String,
          attributes: T::Hash[T.anything, T.anything],
          links: T.nilable(T::Array[T.anything]),
          kind: T.nilable(Symbol),
          exception: T.nilable(Exception),
          even_during_replay: T::Boolean,
          block: T.proc.returns(T.type_parameter(:T))
        ).returns(T.type_parameter(:T))
    end
    def with_completed_span(
      name,
      attributes: T.unsafe(nil),
      links: T.unsafe(nil),
      kind: T.unsafe(nil),
      exception: T.unsafe(nil),
      even_during_replay: T.unsafe(nil),
      &block
    ); end

    sig do
      params(
        name: String,
        attributes: T::Hash[T.anything, T.anything],
        links: T.nilable(T::Array[T.anything]),
        kind: T.nilable(Symbol),
        exception: T.nilable(Exception),
        even_during_replay: T::Boolean
      ).returns(T.anything)
    end
    def completed_span(
      name,
      attributes: T.unsafe(nil),
      links: T.unsafe(nil),
      kind: T.unsafe(nil),
      exception: T.unsafe(nil),
      even_during_replay: T.unsafe(nil)
    ); end
  end
end
