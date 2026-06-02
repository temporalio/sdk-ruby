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
  attr_reader :workflow_id

  sig { returns(String) }
  attr_reader :workflow_type

  sig { returns(T.nilable(String)) }
  attr_reader :run_id
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
  attr_reader :details

  sig { returns(T.nilable(String)) }
  attr_reader :type

  sig { returns(T::Boolean) }
  attr_reader :non_retryable

  sig { returns(T.nilable(T.any(Integer, Float))) }
  attr_reader :next_retry_delay

  sig { returns(Integer) }
  attr_reader :category

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
  attr_reader :details
end

class Temporalio::Error::TerminatedError < ::Temporalio::Error::Failure
  sig { params(message: String, details: T::Array[T.nilable(Object)]).void }
  def initialize(message, details:); end

  sig { returns(T::Array[T.nilable(Object)]) }
  attr_reader :details
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
  attr_reader :type

  sig { returns(T::Array[T.nilable(Object)]) }
  attr_reader :last_heartbeat_details
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
  attr_reader :non_retryable

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
  attr_reader :scheduled_event_id

  sig { returns(Integer) }
  attr_reader :started_event_id

  sig { returns(String) }
  attr_reader :identity

  sig { returns(String) }
  attr_reader :activity_type

  sig { returns(String) }
  attr_reader :activity_id

  sig { returns(T.nilable(Integer)) }
  attr_reader :retry_state
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
  attr_reader :namespace

  sig { returns(String) }
  attr_reader :workflow_id

  sig { returns(String) }
  attr_reader :run_id

  sig { returns(String) }
  attr_reader :workflow_type

  sig { returns(Integer) }
  attr_reader :initiated_event_id

  sig { returns(Integer) }
  attr_reader :started_event_id

  sig { returns(T.nilable(Integer)) }
  attr_reader :retry_state
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
  attr_reader :endpoint

  sig { returns(String) }
  attr_reader :service

  sig { returns(String) }
  attr_reader :operation

  sig { returns(T.nilable(String)) }
  attr_reader :operation_token
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
  attr_reader :error_type

  sig { returns(Integer) }
  attr_reader :retry_behavior
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
  attr_reader :details
end

class Temporalio::Error::WorkflowFailedError < ::Temporalio::Error
  sig { params(message: T.nilable(String)).void }
  def initialize(message = nil); end
end

class Temporalio::Error::WorkflowContinuedAsNewError < ::Temporalio::Error
  sig { params(new_run_id: String).void }
  def initialize(new_run_id:); end

  sig { returns(String) }
  attr_reader :new_run_id
end

class Temporalio::Error::WorkflowQueryFailedError < ::Temporalio::Error; end

class Temporalio::Error::WorkflowQueryRejectedError < ::Temporalio::Error
  sig { params(status: Integer).void }
  def initialize(status:); end

  sig { returns(Integer) }
  attr_reader :status
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
  attr_reader :code

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
