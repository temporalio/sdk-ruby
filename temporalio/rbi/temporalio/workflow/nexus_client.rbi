# typed: true

# Sorbet RBI types for the Temporal Ruby SDK.
# This file was split from rbi/temporalio.rbi by extra/split_rbi.rb.

class Temporalio::Workflow::NexusClient
  extend T::Sig

  sig { returns(String) }
  def endpoint; end

  sig { returns(String) }
  def service; end

  sig do
    params(
      operation: T.any(Symbol, String),
      arg: T.nilable(Object),
      schedule_to_close_timeout: T.nilable(T.any(Integer, Float)),
      schedule_to_start_timeout: T.nilable(T.any(Integer, Float)),
      start_to_close_timeout: T.nilable(T.any(Integer, Float)),
      cancellation_type: Integer,
      summary: T.nilable(String),
      cancellation: Temporalio::Cancellation,
      arg_hint: T.nilable(Object),
      result_hint: T.nilable(Object)
    ).returns(Temporalio::Workflow::NexusOperationHandle)
  end
  def start_operation(
    operation,
    arg,
    schedule_to_close_timeout: T.unsafe(nil),
    schedule_to_start_timeout: T.unsafe(nil),
    start_to_close_timeout: T.unsafe(nil),
    cancellation_type: T.unsafe(nil),
    summary: T.unsafe(nil),
    cancellation: T.unsafe(nil),
    arg_hint: T.unsafe(nil),
    result_hint: T.unsafe(nil)
  ); end

  sig do
    params(
      operation: T.any(Symbol, String),
      arg: T.nilable(Object),
      schedule_to_close_timeout: T.nilable(T.any(Integer, Float)),
      schedule_to_start_timeout: T.nilable(T.any(Integer, Float)),
      start_to_close_timeout: T.nilable(T.any(Integer, Float)),
      cancellation_type: Integer,
      summary: T.nilable(String),
      cancellation: Temporalio::Cancellation,
      arg_hint: T.nilable(Object),
      result_hint: T.nilable(Object)
    ).returns(T.nilable(Object))
  end
  def execute_operation(
    operation,
    arg,
    schedule_to_close_timeout: T.unsafe(nil),
    schedule_to_start_timeout: T.unsafe(nil),
    start_to_close_timeout: T.unsafe(nil),
    cancellation_type: T.unsafe(nil),
    summary: T.unsafe(nil),
    cancellation: T.unsafe(nil),
    arg_hint: T.unsafe(nil),
    result_hint: T.unsafe(nil)
  ); end
end
