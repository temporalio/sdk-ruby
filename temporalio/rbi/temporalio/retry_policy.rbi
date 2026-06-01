# typed: true

# Sorbet RBI types for the Temporal Ruby SDK.
# This file was split from rbi/temporalio.rbi by extra/split_rbi.rb.

class Temporalio::RetryPolicy < ::Data
  sig do
    params(
      initial_interval: T.any(Integer, Float),
      backoff_coefficient: T.any(Integer, Float),
      max_interval: T.nilable(T.any(Integer, Float)),
      max_attempts: Integer,
      non_retryable_error_types: T.nilable(T::Array[String])
    ).void
  end
  def initialize(initial_interval: 1.0, backoff_coefficient: 2.0, max_interval: nil, max_attempts: 0, non_retryable_error_types: nil); end

  sig { returns(T.any(Integer, Float)) }
  def initial_interval; end

  sig { returns(T.any(Integer, Float)) }
  def backoff_coefficient; end

  sig { returns(T.nilable(T.any(Integer, Float))) }
  def max_interval; end

  sig { returns(Integer) }
  def max_attempts; end

  sig { returns(T.nilable(T::Array[String])) }
  def non_retryable_error_types; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::RetryPolicy) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end

    sig { params(args: T.untyped).returns(Temporalio::RetryPolicy) }
    def new(*args); end
  end
end
