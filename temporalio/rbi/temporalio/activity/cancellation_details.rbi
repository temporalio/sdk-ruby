# typed: true

# Sorbet RBI types for the Temporal Ruby SDK.
# This file was split from rbi/temporalio.rbi by extra/split_rbi.rb.

class Temporalio::Activity::CancellationDetails
  sig do
    params(
      gone_from_server: T::Boolean,
      cancel_requested: T::Boolean,
      timed_out: T::Boolean,
      worker_shutdown: T::Boolean,
      paused: T::Boolean,
      reset: T::Boolean
    ).void
  end
  def initialize(gone_from_server: false, cancel_requested: false, timed_out: false, worker_shutdown: false, paused: false, reset: false); end

  sig { returns(T::Boolean) }
  def gone_from_server?; end

  sig { returns(T::Boolean) }
  def cancel_requested?; end

  sig { returns(T::Boolean) }
  def timed_out?; end

  sig { returns(T::Boolean) }
  def worker_shutdown?; end

  sig { returns(T::Boolean) }
  def paused?; end

  sig { returns(T::Boolean) }
  def reset?; end
end
