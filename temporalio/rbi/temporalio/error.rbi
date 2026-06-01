# typed: true

# Sorbet RBI types for the Temporal Ruby SDK.
# This file was split from rbi/temporalio.rbi by extra/split_rbi.rb.

class Temporalio::Error < ::StandardError
  sig { params(error: Exception).returns(T::Boolean) }
  def self.canceled?(error); end
end

class Temporalio::Error::WorkflowAlreadyStartedError < ::Temporalio::Error::Failure
  sig { params(workflow_id: String, workflow_type: String, run_id: T.nilable(String)).void }
  def initialize(workflow_id:, workflow_type:, run_id:); end

  sig { returns(String) }
  def workflow_id; end

  sig { returns(String) }
  def workflow_type; end

  sig { returns(T.nilable(String)) }
  def run_id; end
end

class Temporalio::Error::ApplicationError < ::Temporalio::Error::Failure
  sig do
    params(
      message: String,
      details: T.nilable(Object),
      type: T.nilable(String),
      non_retryable: T::Boolean,
      next_retry_delay: T.nilable(T.any(Integer, Float)),
      category: Integer
    ).void
  end
  def initialize(message, *details, type: nil, non_retryable: false, next_retry_delay: nil, category: T.unsafe(nil)); end

  sig { returns(T::Array[T.nilable(Object)]) }
  def details; end

  sig { returns(T.nilable(String)) }
  def type; end

  sig { returns(T::Boolean) }
  def non_retryable; end

  sig { returns(T.nilable(T.any(Integer, Float))) }
  def next_retry_delay; end

  sig { returns(Integer) }
  def category; end

  sig { returns(T::Boolean) }
  def retryable?; end
end

module Temporalio::Error::ApplicationError::Category
  UNSPECIFIED = T.let(T.unsafe(nil), Integer)
  BENIGN = T.let(T.unsafe(nil), Integer)
end

class Temporalio::Error::CanceledError < ::Temporalio::Error::Failure
  sig { params(message: String, details: T::Array[T.nilable(Object)]).void }
  def initialize(message, details: []); end

  sig { returns(T::Array[T.nilable(Object)]) }
  def details; end
end

class Temporalio::Error::TerminatedError < ::Temporalio::Error::Failure
  sig { params(message: String, details: T::Array[T.nilable(Object)]).void }
  def initialize(message, details:); end

  sig { returns(T::Array[T.nilable(Object)]) }
  def details; end
end

class Temporalio::Error::TimeoutError < ::Temporalio::Error::Failure
  sig do
    params(
      message: String,
      type: Integer,
      last_heartbeat_details: T::Array[T.nilable(Object)]
    ).void
  end
  def initialize(message, type:, last_heartbeat_details:); end

  sig { returns(Integer) }
  def type; end

  sig { returns(T::Array[T.nilable(Object)]) }
  def last_heartbeat_details; end
end

module Temporalio::Error::TimeoutError::TimeoutType
  START_TO_CLOSE = T.let(T.unsafe(nil), Integer)
  SCHEDULE_TO_START = T.let(T.unsafe(nil), Integer)
  SCHEDULE_TO_CLOSE = T.let(T.unsafe(nil), Integer)
  HEARTBEAT = T.let(T.unsafe(nil), Integer)
end

class Temporalio::Error::ServerError < ::Temporalio::Error::Failure
  sig { params(message: String, non_retryable: T::Boolean).void }
  def initialize(message, non_retryable:); end

  sig { returns(T::Boolean) }
  def non_retryable; end

  sig { returns(T::Boolean) }
  def retryable?; end
end

module Temporalio::Error::RetryState
  IN_PROGRESS = T.let(T.unsafe(nil), Integer)
  NON_RETRYABLE_FAILURE = T.let(T.unsafe(nil), Integer)
  TIMEOUT = T.let(T.unsafe(nil), Integer)
  MAXIMUM_ATTEMPTS_REACHED = T.let(T.unsafe(nil), Integer)
  RETRY_POLICY_NOT_SET = T.let(T.unsafe(nil), Integer)
  INTERNAL_SERVER_ERROR = T.let(T.unsafe(nil), Integer)
  CANCEL_REQUESTED = T.let(T.unsafe(nil), Integer)
end

class Temporalio::Error::ActivityError < ::Temporalio::Error::Failure
  sig do
    params(
      message: String,
      scheduled_event_id: Integer,
      started_event_id: Integer,
      identity: String,
      activity_type: String,
      activity_id: String,
      retry_state: T.nilable(Integer)
    ).void
  end
  def initialize(message, scheduled_event_id:, started_event_id:, identity:, activity_type:, activity_id:, retry_state:); end

  sig { returns(Integer) }
  def scheduled_event_id; end

  sig { returns(Integer) }
  def started_event_id; end

  sig { returns(String) }
  def identity; end

  sig { returns(String) }
  def activity_type; end

  sig { returns(String) }
  def activity_id; end

  sig { returns(T.nilable(Integer)) }
  def retry_state; end
end

class Temporalio::Error::ChildWorkflowError < ::Temporalio::Error::Failure
  sig do
    params(
      message: String,
      namespace: String,
      workflow_id: String,
      run_id: String,
      workflow_type: String,
      initiated_event_id: Integer,
      started_event_id: Integer,
      retry_state: T.nilable(Integer)
    ).void
  end
  def initialize(message, namespace:, workflow_id:, run_id:, workflow_type:, initiated_event_id:, started_event_id:, retry_state:); end

  sig { returns(String) }
  def namespace; end

  sig { returns(String) }
  def workflow_id; end

  sig { returns(String) }
  def run_id; end

  sig { returns(String) }
  def workflow_type; end

  sig { returns(Integer) }
  def initiated_event_id; end

  sig { returns(Integer) }
  def started_event_id; end

  sig { returns(T.nilable(Integer)) }
  def retry_state; end
end

class Temporalio::Error::NexusOperationError < ::Temporalio::Error::Failure
  sig do
    params(
      message: String,
      endpoint: String,
      service: String,
      operation: String,
      operation_token: T.nilable(String)
    ).void
  end
  def initialize(message, endpoint:, service:, operation:, operation_token:); end

  sig { returns(String) }
  def endpoint; end

  sig { returns(String) }
  def service; end

  sig { returns(String) }
  def operation; end

  sig { returns(T.nilable(String)) }
  def operation_token; end
end

class Temporalio::Error::NexusHandlerError < ::Temporalio::Error::Failure
  sig do
    params(
      message: String,
      error_type: T.any(Symbol, String),
      retry_behavior: Integer
    ).void
  end
  def initialize(message, error_type:, retry_behavior:); end

  sig { returns(Symbol) }
  def error_type; end

  sig { returns(Integer) }
  def retry_behavior; end
end

module Temporalio::Error::NexusHandlerError::RetryBehavior
  UNSPECIFIED = T.let(T.unsafe(nil), Integer)
  RETRYABLE = T.let(T.unsafe(nil), Integer)
  NON_RETRYABLE = T.let(T.unsafe(nil), Integer)
end

class Temporalio::Error::AsyncActivityCanceledError < ::Temporalio::Error
  sig { params(details: Temporalio::Activity::CancellationDetails).void }
  def initialize(details); end

  sig { returns(Temporalio::Activity::CancellationDetails) }
  def details; end
end

class Temporalio::Error::WorkflowFailedError < ::Temporalio::Error
  sig { params(message: T.nilable(String)).void }
  def initialize(message = nil); end
end

class Temporalio::Error::WorkflowContinuedAsNewError < ::Temporalio::Error
  sig { params(new_run_id: String).void }
  def initialize(new_run_id:); end

  sig { returns(String) }
  def new_run_id; end
end

class Temporalio::Error::WorkflowQueryFailedError < ::Temporalio::Error; end

class Temporalio::Error::WorkflowQueryRejectedError < ::Temporalio::Error
  sig { params(status: Integer).void }
  def initialize(status:); end

  sig { returns(Integer) }
  def status; end
end

class Temporalio::Error::WorkflowUpdateFailedError < ::Temporalio::Error
  sig { void }
  def initialize; end
end

class Temporalio::Error::WorkflowUpdateRPCTimeoutOrCanceledError < ::Temporalio::Error
  sig { void }
  def initialize; end
end

class Temporalio::Error::ScheduleAlreadyRunningError < ::Temporalio::Error
  sig { void }
  def initialize; end
end

class Temporalio::Error::RPCError < ::Temporalio::Error
  sig { params(message: String, code: Integer, raw_grpc_status: T.nilable(Object)).void }
  def initialize(message, code:, raw_grpc_status:); end

  sig { returns(Integer) }
  def code; end

  sig { returns(Temporalio::Api::Common::V1::GrpcStatus) }
  def grpc_status; end
end

module Temporalio::Error::RPCError::Code
  OK = T.let(T.unsafe(nil), Integer)
  CANCELED = T.let(T.unsafe(nil), Integer)
  UNKNOWN = T.let(T.unsafe(nil), Integer)
  INVALID_ARGUMENT = T.let(T.unsafe(nil), Integer)
  DEADLINE_EXCEEDED = T.let(T.unsafe(nil), Integer)
  NOT_FOUND = T.let(T.unsafe(nil), Integer)
  ALREADY_EXISTS = T.let(T.unsafe(nil), Integer)
  PERMISSION_DENIED = T.let(T.unsafe(nil), Integer)
  RESOURCE_EXHAUSTED = T.let(T.unsafe(nil), Integer)
  FAILED_PRECONDITION = T.let(T.unsafe(nil), Integer)
  ABORTED = T.let(T.unsafe(nil), Integer)
  OUT_OF_RANGE = T.let(T.unsafe(nil), Integer)
  UNIMPLEMENTED = T.let(T.unsafe(nil), Integer)
  INTERNAL = T.let(T.unsafe(nil), Integer)
  UNAVAILABLE = T.let(T.unsafe(nil), Integer)
  DATA_LOSS = T.let(T.unsafe(nil), Integer)
  UNAUTHENTICATED = T.let(T.unsafe(nil), Integer)
end
