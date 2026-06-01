# typed: true

# Sorbet RBI types for the Temporal Ruby SDK.
# This file was split from rbi/temporalio.rbi by extra/split_rbi.rb.

class Temporalio::Runtime::MetricBuffer
  extend T::Sig

  sig { params(buffer_size: Integer, duration_format: Symbol).void }
  def initialize(buffer_size, duration_format: T.unsafe(nil)); end

  sig { returns(T::Array[Temporalio::Runtime::MetricBuffer::Update]) }
  def retrieve_updates; end

  module DurationFormat
    MILLISECONDS = T.let(T.unsafe(nil), Symbol)
    SECONDS = T.let(T.unsafe(nil), Symbol)
  end
end

class Temporalio::Runtime::MetricBuffer::Update < ::Data
  extend T::Sig

  sig { returns(Temporalio::Runtime::MetricBuffer::Metric) }
  def metric; end

  sig { returns(T.any(Integer, Float)) }
  def value; end

  sig { returns(T::Hash[String, T.any(String, Integer, Float, T::Boolean)]) }
  def attributes; end
end

class Temporalio::Runtime::MetricBuffer::Metric < ::Data
  extend T::Sig

  sig { returns(String) }
  def name; end

  sig { returns(T.nilable(String)) }
  def description; end

  sig { returns(T.nilable(String)) }
  def unit; end

  sig { returns(Symbol) }
  def kind; end
end
