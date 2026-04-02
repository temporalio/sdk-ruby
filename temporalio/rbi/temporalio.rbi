# typed: true

# Enriched Sorbet RBI types for the Temporal Ruby SDK.
# These types are hand-maintained from the RBS signatures in sig/.
# See https://github.com/temporalio/sdk-ruby for documentation.

module Temporalio
  VERSION = T.let(T.unsafe(nil), String)
end

# Protobuf API types. Only commonly-referenced types are included here.
# The full set of protobuf types is available via the google-protobuf gem.
module Temporalio::Api; end
module Temporalio::Api::Common; end
module Temporalio::Api::Common::V1; end
class Temporalio::Api::Common::V1::Payload
  extend T::Sig

  sig { params(kwargs: T.untyped).void }
  def initialize(**kwargs); end

  sig { returns(T::Hash[String, String]) }
  def metadata; end

  sig { returns(String) }
  def data; end

  sig { returns(String) }
  def to_proto; end

  class << self
    extend T::Sig

    sig { params(data: String).returns(Temporalio::Api::Common::V1::Payload) }
    def decode(data); end
  end
end

class Temporalio::Api::Common::V1::Payloads
  extend T::Sig

  sig { params(kwargs: T.untyped).void }
  def initialize(**kwargs); end

  sig { returns(T::Array[Temporalio::Api::Common::V1::Payload]) }
  def payloads; end
end

# All activity related classes.
module Temporalio::Activity; end

# Details that are set when an activity is cancelled. This is only valid at the time the cancel was received, the
# state may change on the server after it is received.
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

  # @return [Boolean] Whether the activity no longer exists on the server (may already be completed or its workflow
  #   may be completed).
  sig { returns(T::Boolean) }
  def gone_from_server?; end

  # @return [Boolean] Whether the activity was explicitly cancelled.
  sig { returns(T::Boolean) }
  def cancel_requested?; end

  # @return [Boolean] Whether the activity timeout caused activity to be marked cancelled.
  sig { returns(T::Boolean) }
  def timed_out?; end

  # @return [Boolean] Whether the worker the activity is running on is shutting down.
  sig { returns(T::Boolean) }
  def worker_shutdown?; end

  # @return [Boolean] Whether the activity was explicitly paused.
  sig { returns(T::Boolean) }
  def paused?; end

  # @return [Boolean] Whether the activity was explicitly reset.
  sig { returns(T::Boolean) }
  def reset?; end
end

# Error raised inside an activity to mark that the activity will be completed asynchronously.
class Temporalio::Activity::CompleteAsyncError < ::Temporalio::Error; end

# Context accessible only within an activity. Use {current} to get the current context. Contexts are fiber or thread
# local so may not be available in a newly started thread from an activity and may have to be propagated manually.
class Temporalio::Activity::Context
  # @return [Context] The current context, or raises an error if not in activity fiber/thread.
  sig { returns(Temporalio::Activity::Context) }
  def self.current; end

  # @return [Context, nil] The current context or nil if not in activity fiber/thread.
  sig { returns(T.nilable(Temporalio::Activity::Context)) }
  def self.current_or_nil; end

  # @return [Boolean] Whether there is a current context available.
  sig { returns(T::Boolean) }
  def self.exist?; end

  # @return [Info] Activity info for this activity.
  sig { returns(Temporalio::Activity::Info) }
  def info; end

  # @return [Object, nil] Activity class instance.
  sig { returns(T.nilable(Temporalio::Activity::Definition)) }
  def instance; end

  # Record a heartbeat on the activity.
  #
  # @param details [Array<Object>] Details to record with the heartbeat.
  # @param detail_hints [Array<Object>, nil] Hints to pass to converter.
  sig { params(details: T.untyped, detail_hints: T.nilable(T::Array[Object])).void }
  def heartbeat(*details, detail_hints: nil); end

  # @return [Cancellation] Cancellation that is canceled when the activity is canceled.
  sig { returns(Temporalio::Cancellation) }
  def cancellation; end

  # @return [CancellationDetails, nil] Cancellation details if canceled.
  sig { returns(T.nilable(Temporalio::Activity::CancellationDetails)) }
  def cancellation_details; end

  # @return [Cancellation] Cancellation that is canceled when the worker is shutting down.
  sig { returns(Temporalio::Cancellation) }
  def worker_shutdown_cancellation; end

  # @return [Converters::PayloadConverter] Payload converter associated with this activity.
  sig { returns(Temporalio::Converters::PayloadConverter) }
  def payload_converter; end

  # @return [ScopedLogger] Logger for this activity.
  sig { returns(Temporalio::ScopedLogger) }
  def logger; end

  # @return [Metric::Meter] Metric meter to create metrics on, with some activity-specific attributes already set.
  sig { returns(Temporalio::Metric::Meter) }
  def metric_meter; end

  # @return [Client] Temporal client this activity worker is running in.
  sig { returns(Temporalio::Client) }
  def client; end
end

# Base class for all activities.
#
# Activities can be given to a worker as instances of this class, which will call execute on the same instance for
# each execution, or given to the worker as the class itself which instantiates the activity for each execution.
class Temporalio::Activity::Definition
  # Implementation of the activity.
  sig { params(args: T.untyped).returns(T.untyped) }
  def execute(*args); end

  class << self
    protected

    # Override the activity name which is defaulted to the unqualified class name.
    #
    # @param name [String, Symbol] Name to use.
    sig { params(name: T.any(String, Symbol)).void }
    def activity_name(name); end

    # Override the activity executor which is defaulted to `:default`.
    #
    # @param executor_name [Symbol] Executor to use.
    sig { params(executor_name: Symbol).void }
    def activity_executor(executor_name); end

    # Override whether the activity uses Thread/Fiber raise for cancellation which is defaulted to true.
    #
    # @param cancel_raise [Boolean] Whether to raise.
    sig { params(cancel_raise: T::Boolean).void }
    def activity_cancel_raise(cancel_raise); end

    # Set an activity as dynamic.
    #
    # @param value [Boolean] Whether the activity is dynamic.
    sig { params(value: T::Boolean).void }
    def activity_dynamic(value = true); end

    # Have activity arguments delivered to `execute` as {Converters::RawValue}s.
    #
    # @param value [Boolean] Whether the activity accepts raw arguments.
    sig { params(value: T::Boolean).void }
    def activity_raw_args(value = true); end

    # Add activity hints to be passed to converter for activity args.
    #
    # @param hints [Array<Object>] Hints to add.
    sig { params(hints: Object).void }
    def activity_arg_hint(*hints); end

    # Set activity result hint to be passed to converter for activity result.
    #
    # @param hint [Object] Hint to set.
    sig { params(hint: T.nilable(Object)).void }
    def activity_result_hint(hint); end
  end
end

# Definition info of an activity. Activities are usually classes/instances that extend {Definition}, but
# definitions can also be manually created with a block via {initialize} here.
class Temporalio::Activity::Definition::Info
  # @param name [String, Symbol, nil] Name of the activity or nil for dynamic activity.
  # @param instance [Object, Proc, nil] The pre-created instance or the proc to create/return it.
  # @param executor [Symbol] Name of the executor.
  # @param cancel_raise [Boolean] Whether to raise in thread/fiber on cancellation.
  # @param raw_args [Boolean] Whether to use {Converters::RawValue}s as arguments.
  # @param arg_hints [Array<Object>, nil] Argument hints.
  # @param result_hint [Object, nil] Result hint.
  sig do
    params(
      name: T.nilable(T.any(String, Symbol)),
      instance: T.nilable(T.any(Object, Proc)),
      executor: Symbol,
      cancel_raise: T::Boolean,
      raw_args: T::Boolean,
      arg_hints: T.nilable(T::Array[Object]),
      result_hint: T.nilable(Object),
      block: T.nilable(T.proc.params(arg0: T.untyped).returns(T.untyped))
    ).void
  end
  def initialize(name:, instance: nil, executor: :default, cancel_raise: true, raw_args: false, arg_hints: nil, result_hint: nil, &block); end

  # Obtain definition info representing the given activity.
  #
  # @param activity [Definition, Class<Definition>, Info] Activity to get info for.
  # @return [Info] Obtained definition info.
  sig { params(activity: T.any(Temporalio::Activity::Definition, T.class_of(Temporalio::Activity::Definition), Temporalio::Activity::Definition::Info)).returns(Temporalio::Activity::Definition::Info) }
  def self.from_activity(activity); end

  # @return [String, Symbol, nil] Name of the activity, or nil if the activity is dynamic.
  sig { returns(T.nilable(T.any(String, Symbol))) }
  def name; end

  # @return [Object, Proc, nil] The pre-created instance or the proc to create/return it.
  sig { returns(T.nilable(T.any(Object, Proc))) }
  def instance; end

  # @return [Proc] Proc for the activity.
  sig { returns(Proc) }
  def proc; end

  # @return [Symbol] Name of the executor. Default is `:default`.
  sig { returns(Symbol) }
  def executor; end

  # @return [Boolean] Whether to raise in thread/fiber on cancellation. Default is `true`.
  sig { returns(T::Boolean) }
  def cancel_raise; end

  # @return [Boolean] Whether to use {Converters::RawValue}s as arguments.
  sig { returns(T::Boolean) }
  def raw_args; end

  # @return [Array<Object>, nil] Argument hints.
  sig { returns(T.nilable(T::Array[Object])) }
  def arg_hints; end

  # @return [Object, nil] Result hint.
  sig { returns(T.nilable(Object)) }
  def result_hint; end
end

# Information about an activity.
#
# @note WARNING: This class may have required parameters added to its constructor. Users should not instantiate this
#   class or it may break in incompatible ways.
class Temporalio::Activity::Info < ::Data
  sig do
    params(
      activity_id: String,
      activity_type: String,
      attempt: Integer,
      current_attempt_scheduled_time: Time,
      heartbeat_timeout: T.nilable(Float),
      local: T::Boolean,
      priority: T.nilable(Temporalio::Priority),
      raw_heartbeat_details: T::Array[Temporalio::Converters::RawValue],
      retry_policy: T.nilable(Temporalio::RetryPolicy),
      schedule_to_close_timeout: T.nilable(Float),
      scheduled_time: Time,
      start_to_close_timeout: T.nilable(Float),
      started_time: Time,
      task_queue: String,
      task_token: String,
      workflow_id: String,
      workflow_namespace: String,
      workflow_run_id: String,
      workflow_type: String
    ).void
  end
  def initialize(activity_id:, activity_type:, attempt:, current_attempt_scheduled_time:, heartbeat_timeout:, local:, priority:, raw_heartbeat_details:, retry_policy:, schedule_to_close_timeout:, scheduled_time:, start_to_close_timeout:, started_time:, task_queue:, task_token:, workflow_id:, workflow_namespace:, workflow_run_id:, workflow_type:); end

  # @return [String] ID for the activity.
  sig { returns(String) }
  def activity_id; end

  # @return [String] Type name for the activity.
  sig { returns(String) }
  def activity_type; end

  # @return [Integer] Attempt the activity is on.
  sig { returns(Integer) }
  def attempt; end

  # @return [Time] When the current attempt was scheduled.
  sig { returns(Time) }
  def current_attempt_scheduled_time; end

  # Convert raw heartbeat details into Ruby types.
  #
  # @param hints [Array<Object>, nil] Hints, if any, to assist conversion.
  # @return [Array<Object>] Converted details.
  sig { params(hints: T.nilable(T::Array[Object])).returns(T::Array[T.nilable(Object)]) }
  def heartbeat_details(hints: nil); end

  # @return [Float, nil] Heartbeat timeout set by the caller.
  sig { returns(T.nilable(Float)) }
  def heartbeat_timeout; end

  # @return [Boolean] Whether the activity is a local activity or not.
  sig { returns(T::Boolean) }
  def local?; end

  # @return [Priority] The priority of this activity.
  sig { returns(Temporalio::Priority) }
  def priority; end

  # @return [Array<Converter::RawValue>] Raw details from the last heartbeat of the last attempt.
  sig { returns(T::Array[Temporalio::Converters::RawValue]) }
  def raw_heartbeat_details; end

  # @return [RetryPolicy, nil] Retry policy for the activity.
  sig { returns(T.nilable(Temporalio::RetryPolicy)) }
  def retry_policy; end

  # @return [Float, nil] Schedule to close timeout set by the caller.
  sig { returns(T.nilable(Float)) }
  def schedule_to_close_timeout; end

  # @return [Time] When the activity was scheduled.
  sig { returns(Time) }
  def scheduled_time; end

  # @return [Float, nil] Start to close timeout set by the caller.
  sig { returns(T.nilable(Float)) }
  def start_to_close_timeout; end

  # @return [Time] When the activity started.
  sig { returns(Time) }
  def started_time; end

  # @return [String] Task queue this activity is on.
  sig { returns(String) }
  def task_queue; end

  # @return [String] Task token uniquely identifying this activity.
  sig { returns(String) }
  def task_token; end

  # @return [String] Workflow ID that started this activity.
  sig { returns(String) }
  def workflow_id; end

  # @return [String] Namespace this activity is on.
  sig { returns(String) }
  def workflow_namespace; end

  # @return [String] Workflow run ID that started this activity.
  sig { returns(String) }
  def workflow_run_id; end

  # @return [String] Workflow type name that started this activity.
  sig { returns(String) }
  def workflow_type; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Activity::Info) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end

    sig { params(args: T.untyped).returns(Temporalio::Activity::Info) }
    def new(*args); end
  end
end

# Cancellation token/signal. Can be used to cancel operations and wait for cancellation.
class Temporalio::Cancellation
  # Create a new cancellation.
  #
  # This is usually created and destructured into a tuple with the second value being the proc to invoke to cancel.
  # For example: `cancel, cancel_proc = Temporalio::Cancellation.new`.
  #
  # @param parents [Array<Cancellation>] Parent cancellations to link this one to.
  sig { params(parents: Temporalio::Cancellation).void }
  def initialize(*parents); end

  # @return [Boolean] Whether this cancellation is canceled.
  sig { returns(T::Boolean) }
  def canceled?; end

  # @return [String, nil] Reason for cancellation. Can be nil if not canceled or no reason provided.
  sig { returns(T.nilable(String)) }
  def canceled_reason; end

  # @return [Boolean] Whether a cancel is pending but currently shielded.
  sig { returns(T::Boolean) }
  def pending_canceled?; end

  # @return [String, nil] Reason for pending cancellation. Can be nil if not pending canceled or no reason provided.
  sig { returns(T.nilable(String)) }
  def pending_canceled_reason; end

  # Raise an error if this cancellation is canceled.
  #
  # @param err [Exception] Error to raise.
  sig { params(err: Exception).void }
  def check!(err = T.unsafe(nil)); end

  # @return [Array(Cancellation, Proc)] Self and a proc to call to cancel.
  sig { returns([Temporalio::Cancellation, Proc]) }
  def to_ary; end

  # Wait on this to be canceled.
  sig { void }
  def wait; end

  # Shield the given block from cancellation.
  sig do
    type_parameters(:T)
      .params(blk: T.proc.returns(T.type_parameter(:T)))
      .returns(T.type_parameter(:T))
  end
  def shield(&blk); end

  # Advanced call to invoke a block on cancel.
  #
  # @note WARNING: This is advanced API, users should use {wait} or similar.
  # @return [Object] Key that can be used with {remove_cancel_callback} or nil if run immediately.
  sig { params(block: T.proc.void).returns(Object) }
  def add_cancel_callback(&block); end

  # Remove a cancel callback using the key returned from {add_cancel_callback}.
  #
  # @param key [Object] Key returned from {add_cancel_callback}.
  sig { params(key: Object).void }
  def remove_cancel_callback(key); end
end

# Base error class for all Temporal errors.
class Temporalio::Error < ::StandardError
  # Whether the error represents some form of cancellation from an activity or workflow.
  #
  # @param error [Exception] Error to check.
  # @return [Boolean] True if some form of canceled, false otherwise.
  sig { params(error: Exception).returns(T::Boolean) }
  def self.canceled?(error); end
end

# Base class for all Temporal serializable failures.
class Temporalio::Error::Failure < ::Temporalio::Error; end

# Error raised by a client or workflow when a workflow execution has already started.
class Temporalio::Error::WorkflowAlreadyStartedError < ::Temporalio::Error::Failure
  sig { params(workflow_id: String, workflow_type: String, run_id: T.nilable(String)).void }
  def initialize(workflow_id:, workflow_type:, run_id:); end

  # @return [String] ID of the already-started workflow.
  sig { returns(String) }
  def workflow_id; end

  # @return [String] Workflow type name of the already-started workflow.
  sig { returns(String) }
  def workflow_type; end

  # @return [String, nil] Run ID of the already-started workflow if this was raised by the client.
  sig { returns(T.nilable(String)) }
  def run_id; end
end

# Error raised during workflow/activity execution.
class Temporalio::Error::ApplicationError < ::Temporalio::Error::Failure
  # @param message [String] Error message.
  # @param details [Array<Object, nil>] Error details.
  # @param type [String, nil] Error type.
  # @param non_retryable [Boolean] Whether this error should be considered non-retryable.
  # @param next_retry_delay [Float, nil] Specific amount of time to delay before next retry.
  # @param category [Category] Error category.
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

  # @return [Array<Object, nil>] User-defined details on the error.
  sig { returns(T::Array[T.nilable(Object)]) }
  def details; end

  # @return [String, nil] General error type.
  sig { returns(T.nilable(String)) }
  def type; end

  # @return [Boolean] Whether the error was set as non-retryable when created.
  sig { returns(T::Boolean) }
  def non_retryable; end

  # @return [Float, nil] Delay in seconds before the next activity retry attempt.
  sig { returns(T.nilable(T.any(Integer, Float))) }
  def next_retry_delay; end

  # @return [Category] Error category.
  sig { returns(Integer) }
  def category; end

  # @return [Boolean] Inverse of {non_retryable}.
  sig { returns(T::Boolean) }
  def retryable?; end
end

# Error category.
module Temporalio::Error::ApplicationError::Category
  UNSPECIFIED = T.let(T.unsafe(nil), Integer)
  BENIGN = T.let(T.unsafe(nil), Integer)
end

# Error raised on workflow/activity cancellation.
class Temporalio::Error::CanceledError < ::Temporalio::Error::Failure
  sig { params(message: String, details: T::Array[T.nilable(Object)]).void }
  def initialize(message, details: []); end

  # @return [Array<Object?>] User-defined details on the error.
  sig { returns(T::Array[T.nilable(Object)]) }
  def details; end
end

# Error raised on workflow termination.
class Temporalio::Error::TerminatedError < ::Temporalio::Error::Failure
  sig { params(message: String, details: T::Array[T.nilable(Object)]).void }
  def initialize(message, details:); end

  # @return [Array<Object?>] User-defined details on the error.
  sig { returns(T::Array[T.nilable(Object)]) }
  def details; end
end

# Error raised on workflow/activity timeout.
class Temporalio::Error::TimeoutError < ::Temporalio::Error::Failure
  sig do
    params(
      message: String,
      type: Integer,
      last_heartbeat_details: T::Array[T.nilable(Object)]
    ).void
  end
  def initialize(message, type:, last_heartbeat_details:); end

  # @return [TimeoutType] Type of timeout error.
  sig { returns(Integer) }
  def type; end

  # @return [Array<Object>] Last heartbeat details if this is for an activity heartbeat.
  sig { returns(T::Array[T.nilable(Object)]) }
  def last_heartbeat_details; end
end

# Type of timeout error.
module Temporalio::Error::TimeoutError::TimeoutType
  START_TO_CLOSE = T.let(T.unsafe(nil), Integer)
  SCHEDULE_TO_START = T.let(T.unsafe(nil), Integer)
  SCHEDULE_TO_CLOSE = T.let(T.unsafe(nil), Integer)
  HEARTBEAT = T.let(T.unsafe(nil), Integer)
end

# Error originating in the Temporal server.
class Temporalio::Error::ServerError < ::Temporalio::Error::Failure
  sig { params(message: String, non_retryable: T::Boolean).void }
  def initialize(message, non_retryable:); end

  # @return [Boolean] Whether this error is non-retryable.
  sig { returns(T::Boolean) }
  def non_retryable; end

  # @return [Boolean] Inverse of {non_retryable}.
  sig { returns(T::Boolean) }
  def retryable?; end
end

# Current retry state of the workflow/activity during error.
module Temporalio::Error::RetryState
  IN_PROGRESS = T.let(T.unsafe(nil), Integer)
  NON_RETRYABLE_FAILURE = T.let(T.unsafe(nil), Integer)
  TIMEOUT = T.let(T.unsafe(nil), Integer)
  MAXIMUM_ATTEMPTS_REACHED = T.let(T.unsafe(nil), Integer)
  RETRY_POLICY_NOT_SET = T.let(T.unsafe(nil), Integer)
  INTERNAL_SERVER_ERROR = T.let(T.unsafe(nil), Integer)
  CANCEL_REQUESTED = T.let(T.unsafe(nil), Integer)
end

# Error raised on activity failure.
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

  # @return [Integer] Scheduled event ID for this activity.
  sig { returns(Integer) }
  def scheduled_event_id; end

  # @return [Integer] Started event ID for this activity.
  sig { returns(Integer) }
  def started_event_id; end

  # @return [String] Client/worker identity.
  sig { returns(String) }
  def identity; end

  # @return [String] Activity type name.
  sig { returns(String) }
  def activity_type; end

  # @return [String] Activity ID.
  sig { returns(String) }
  def activity_id; end

  # @return [RetryState, nil] Retry state.
  sig { returns(T.nilable(Integer)) }
  def retry_state; end
end

# Error raised on child workflow failure.
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

  # @return [String] Child workflow namespace.
  sig { returns(String) }
  def namespace; end

  # @return [String] Child workflow ID.
  sig { returns(String) }
  def workflow_id; end

  # @return [String] Child workflow run ID.
  sig { returns(String) }
  def run_id; end

  # @return [String] Child workflow type name.
  sig { returns(String) }
  def workflow_type; end

  # @return [Integer] Child workflow initiated event ID.
  sig { returns(Integer) }
  def initiated_event_id; end

  # @return [Integer] Child workflow started event ID.
  sig { returns(Integer) }
  def started_event_id; end

  # @return [RetryState, nil] Retry state.
  sig { returns(T.nilable(Integer)) }
  def retry_state; end
end

# Error raised on Nexus operation failure.
#
# WARNING: Nexus support is experimental.
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

  # @return [String] Nexus endpoint.
  sig { returns(String) }
  def endpoint; end

  # @return [String] Nexus service.
  sig { returns(String) }
  def service; end

  # @return [String] Nexus operation.
  sig { returns(String) }
  def operation; end

  # @return [String, nil] Operation token for async operations.
  sig { returns(T.nilable(String)) }
  def operation_token; end
end

# Error raised from a Nexus handler.
#
# WARNING: Nexus support is experimental.
class Temporalio::Error::NexusHandlerError < ::Temporalio::Error::Failure
  sig do
    params(
      message: String,
      error_type: T.any(Symbol, String),
      retry_behavior: Integer
    ).void
  end
  def initialize(message, error_type:, retry_behavior:); end

  # @return [Symbol] Error type from the handler.
  sig { returns(Symbol) }
  def error_type; end

  # @return [RetryBehavior] Retry behavior for the error.
  sig { returns(Integer) }
  def retry_behavior; end
end

# Nexus handler error retry behavior.
module Temporalio::Error::NexusHandlerError::RetryBehavior
  UNSPECIFIED = T.let(T.unsafe(nil), Integer)
  RETRYABLE = T.let(T.unsafe(nil), Integer)
  NON_RETRYABLE = T.let(T.unsafe(nil), Integer)
end

# Error that occurs when an async activity handle tries to heartbeat and the activity is marked as canceled.
class Temporalio::Error::AsyncActivityCanceledError < ::Temporalio::Error
  sig { params(details: Temporalio::Activity::CancellationDetails).void }
  def initialize(details); end

  # @return [Activity::CancellationDetails]
  sig { returns(Temporalio::Activity::CancellationDetails) }
  def details; end
end

# Error that is returned when a workflow is unsuccessful.
class Temporalio::Error::WorkflowFailedError < ::Temporalio::Error
  sig { params(message: T.nilable(String)).void }
  def initialize(message = nil); end
end

# Error that occurs when a workflow was continued as new.
class Temporalio::Error::WorkflowContinuedAsNewError < ::Temporalio::Error
  sig { params(new_run_id: String).void }
  def initialize(new_run_id:); end

  # @return [String] New execution run ID the workflow continued to.
  sig { returns(String) }
  def new_run_id; end
end

# Error that occurs when a query fails.
class Temporalio::Error::WorkflowQueryFailedError < ::Temporalio::Error; end

# Error that occurs when a query was rejected.
class Temporalio::Error::WorkflowQueryRejectedError < ::Temporalio::Error
  sig { params(status: Integer).void }
  def initialize(status:); end

  # @return [Client::WorkflowExecutionStatus] Workflow execution status causing rejection.
  sig { returns(Integer) }
  def status; end
end

# Error that occurs when an update fails.
class Temporalio::Error::WorkflowUpdateFailedError < ::Temporalio::Error
  sig { void }
  def initialize; end
end

# Error that occurs when update RPC call times out or is canceled.
#
# @note This is not related to any general concept of timing out or cancelling a running update, this is only
#   related to the client call itself.
class Temporalio::Error::WorkflowUpdateRPCTimeoutOrCanceledError < ::Temporalio::Error
  sig { void }
  def initialize; end
end

# Error when a schedule is already running.
class Temporalio::Error::ScheduleAlreadyRunningError < ::Temporalio::Error
  sig { void }
  def initialize; end
end

# Error raised by a client for a general RPC failure.
class Temporalio::Error::RPCError < ::Temporalio::Error
  sig { params(message: String, code: Integer, raw_grpc_status: T.untyped).void }
  def initialize(message, code:, raw_grpc_status:); end

  # @return [Code] Status code for the error.
  sig { returns(Integer) }
  def code; end

  # @return [Api::Common::V1::GrpcStatus] Status of the gRPC call with details.
  sig { returns(T.untyped) }
  def grpc_status; end
end

# Status code for RPC errors. These are gRPC status codes.
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

# Priority contains metadata that controls relative ordering of task processing when tasks are
# backlogged in a queue.
class Temporalio::Priority < ::Data
  # @param priority_key [Integer, nil] The priority key.
  # @param fairness_key [String, nil] The fairness key.
  # @param fairness_weight [Float, nil] The fairness weight.
  sig do
    params(
      priority_key: T.nilable(Integer),
      fairness_key: T.nilable(String),
      fairness_weight: T.nilable(Float)
    ).void
  end
  def initialize(priority_key: nil, fairness_key: nil, fairness_weight: nil); end

  # The default priority instance.
  #
  # @return [Priority] The default priority.
  sig { returns(Temporalio::Priority) }
  def self.default; end

  # @return [Integer, nil] The priority key.
  sig { returns(T.nilable(Integer)) }
  def priority_key; end

  # @return [String, nil] The fairness key.
  sig { returns(T.nilable(String)) }
  def fairness_key; end

  # @return [Float, nil] The fairness weight.
  sig { returns(T.nilable(Float)) }
  def fairness_weight; end

  # @return [Boolean] True if this priority is empty/default.
  sig { returns(T::Boolean) }
  def empty?; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Priority) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end

    sig { params(args: T.untyped).returns(Temporalio::Priority) }
    def new(*args); end
  end
end

# Options for retrying workflows and activities.
class Temporalio::RetryPolicy < ::Data
  # @param initial_interval [Float] Backoff interval in seconds for the first retry. Default 1.0.
  # @param backoff_coefficient [Float] Coefficient to multiply previous backoff interval by to get new interval.
  #   Default 2.0.
  # @param max_interval [Float, nil] Maximum backoff interval in seconds between retries. Default 100x
  #   `initial_interval`.
  # @param max_attempts [Integer] Maximum number of attempts. If `0`, the default, there is no maximum.
  # @param non_retryable_error_types [Array<String>, nil] List of error types that are not retryable.
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

  # @return [Float] Backoff interval in seconds for the first retry. Default 1.0.
  sig { returns(T.any(Integer, Float)) }
  def initial_interval; end

  # @return [Float] Coefficient to multiply previous backoff interval by to get new interval. Default 2.0.
  sig { returns(T.any(Integer, Float)) }
  def backoff_coefficient; end

  # @return [Float, nil] Maximum backoff interval in seconds between retries. Default 100x `initial_interval`.
  sig { returns(T.nilable(T.any(Integer, Float))) }
  def max_interval; end

  # @return [Integer] Maximum number of attempts. If `0`, the default, there is no maximum.
  sig { returns(Integer) }
  def max_attempts; end

  # @return [Array<String>, nil] List of error types that are not retryable.
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

# Collection of typed search attributes.
#
# This is represented as a mapping of {SearchAttributes::Key} to object values.
class Temporalio::SearchAttributes
  # Create a search attribute collection.
  #
  # @param existing [SearchAttributes, Hash<Key, Object>, nil] Existing collection.
  sig { params(existing: T.nilable(T.any(Temporalio::SearchAttributes, T::Hash[Temporalio::SearchAttributes::Key, Object]))).void }
  def initialize(existing = nil); end

  # Set a search attribute value for a key.
  #
  # @param key [Key] A key to set.
  # @param value [Object, nil] The value to set. If `nil`, the key is removed.
  sig { params(key: T.any(Temporalio::SearchAttributes::Key, String, Symbol), value: T.nilable(Object)).void }
  def []=(key, value); end

  # Get a search attribute value for a key.
  #
  # @param key [Key] The key to find.
  # @return [Object, nil] Value if found or `nil` if not.
  sig { params(key: Temporalio::SearchAttributes::Key).returns(T.nilable(Object)) }
  def [](key); end

  # Delete a search attribute key.
  #
  # @param key [Key, String, Symbol] The key to delete.
  sig { params(key: T.any(Temporalio::SearchAttributes::Key, String, Symbol)).void }
  def delete(key); end

  # Like {::Hash#each}.
  sig { params(block: T.proc.params(key: Temporalio::SearchAttributes::Key, value: Object).void).returns(Temporalio::SearchAttributes) }
  def each(&block); end

  # @return [Hash<Key, Object>] Copy of the search attributes as a hash.
  sig { returns(T::Hash[Temporalio::SearchAttributes::Key, Object]) }
  def to_h; end

  # @return [SearchAttributes] Copy of the search attributes.
  sig { returns(Temporalio::SearchAttributes) }
  def dup; end

  # @return [Boolean] Whether the set of attributes is empty.
  sig { returns(T::Boolean) }
  def empty?; end

  # @return [Integer] Number of attributes.
  sig { returns(Integer) }
  def length; end

  # @return [Integer] Number of attributes.
  sig { returns(Integer) }
  def size; end

  # Return a new search attributes collection with updates applied.
  #
  # @param updates [Update] Updates created via {Key#value_set} or {Key#value_unset}.
  # @return [SearchAttributes] New collection.
  sig { params(updates: Temporalio::SearchAttributes::Update).returns(Temporalio::SearchAttributes) }
  def update(*updates); end

  # Update this search attribute collection with given updates.
  #
  # @param updates [Update] Updates created via {Key#value_set} or {Key#value_unset}.
  sig { params(updates: Temporalio::SearchAttributes::Update).void }
  def update!(*updates); end

  # Check equality.
  #
  # @param other [SearchAttributes] To compare.
  # @return [Boolean] Whether equal.
  sig { params(other: Temporalio::SearchAttributes).returns(T::Boolean) }
  def ==(other); end
end

# Key for a search attribute.
class Temporalio::SearchAttributes::Key
  # @param name [String] Name of the search attribute.
  # @param type [Integer] Type of the search attribute (from {IndexedValueType}).
  sig { params(name: String, type: Integer).void }
  def initialize(name, type); end

  # @return [String] Name of the search attribute.
  sig { returns(String) }
  def name; end

  # @return [IndexedValueType] Type of the search attribute.
  sig { returns(Integer) }
  def type; end

  # Validate that the given value matches the expected {#type}.
  sig { params(value: Object).void }
  def validate_value(value); end

  # Create an update that sets the given value for this key.
  #
  # @param value [Object] Value to update.
  # @return [Update] Created update.
  sig { params(value: Object).returns(Temporalio::SearchAttributes::Update) }
  def value_set(value); end

  # Create an update that unsets the key.
  #
  # @return [Update] Created update.
  sig { returns(Temporalio::SearchAttributes::Update) }
  def value_unset; end

  # @return [Boolean] Check equality.
  sig { params(other: T.untyped).returns(T::Boolean) }
  def ==(other); end

  # @return [Boolean] Check equality.
  sig { params(other: T.untyped).returns(T::Boolean) }
  def eql?(other); end

  # @return [Integer] Hash.
  sig { returns(Integer) }
  def hash; end
end

# Search attribute update that can be separately applied.
class Temporalio::SearchAttributes::Update
  # @param key [Key] Key to update.
  # @param value [Object, nil] Value to update to or nil to remove the value.
  sig { params(key: Temporalio::SearchAttributes::Key, value: T.nilable(Object)).void }
  def initialize(key, value); end

  # @return [Key] Key this update applies to.
  sig { returns(Temporalio::SearchAttributes::Key) }
  def key; end

  # @return [Object, nil] Value to update or `nil` to remove the key.
  sig { returns(T.nilable(Object)) }
  def value; end
end

# Type for a search attribute key/value.
module Temporalio::SearchAttributes::IndexedValueType
  TEXT = T.let(T.unsafe(nil), Integer)
  KEYWORD = T.let(T.unsafe(nil), Integer)
  INTEGER = T.let(T.unsafe(nil), Integer)
  FLOAT = T.let(T.unsafe(nil), Integer)
  BOOLEAN = T.let(T.unsafe(nil), Integer)
  TIME = T.let(T.unsafe(nil), Integer)
  KEYWORD_LIST = T.let(T.unsafe(nil), Integer)
  PROTO_NAMES = T.let(T.unsafe(nil), T::Hash[Integer, String])
  PROTO_VALUES = T.let(T.unsafe(nil), T::Hash[String, Integer])
end

# Base class for version overrides that can be provided in start workflow options.
class Temporalio::VersioningOverride; end

# Represents a versioning override to pin a workflow to a specific version.
class Temporalio::VersioningOverride::Pinned < ::Temporalio::VersioningOverride
  # @param version [WorkerDeploymentVersion] The worker deployment version to pin to.
  sig { params(version: Temporalio::WorkerDeploymentVersion).void }
  def initialize(version); end

  # @return [WorkerDeploymentVersion] The worker deployment version to pin to.
  sig { returns(Temporalio::WorkerDeploymentVersion) }
  def version; end
end

# Represents a versioning override to auto-upgrade a workflow.
class Temporalio::VersioningOverride::AutoUpgrade < ::Temporalio::VersioningOverride; end

# A worker deployment version, consisting of a deployment name and a build ID.
class Temporalio::WorkerDeploymentVersion < ::Data
  # @param deployment_name [String] The name of the deployment.
  # @param build_id [String] The build identifier specific to this worker build.
  sig { params(deployment_name: String, build_id: String).void }
  def initialize(deployment_name:, build_id:); end

  # Parse a version from a canonical string, which must be in the format
  # `<deployment_name>.<build_id>`.
  #
  # @param canonical [String] The canonical string representation of the version.
  # @return [WorkerDeploymentVersion] The parsed version.
  sig { params(canonical: String).returns(Temporalio::WorkerDeploymentVersion) }
  def self.from_canonical_string(canonical); end

  # @return [String] The name of the deployment.
  sig { returns(String) }
  def deployment_name; end

  # @return [String] The build identifier specific to this worker build.
  sig { returns(String) }
  def build_id; end

  # Returns the canonical string representation of the version.
  #
  # @return [String]
  sig { returns(String) }
  def to_canonical_string; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::WorkerDeploymentVersion) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end

    sig { params(args: T.untyped).returns(Temporalio::WorkerDeploymentVersion) }
    def new(*args); end
  end
end

# Workflow history for replay or conversion.
class Temporalio::WorkflowHistory
  # @param events [Array] History events for the workflow.
  sig { params(events: T::Array[T.untyped]).void }
  def initialize(events); end

  # Convert a JSON string to workflow history.
  #
  # @param json [String] JSON string.
  # @return [WorkflowHistory] Converted history.
  sig { params(json: String).returns(Temporalio::WorkflowHistory) }
  def self.from_history_json(json); end

  # @return [Array<Api::History::V1::HistoryEvent>] History events for the workflow.
  sig { returns(T::Array[T.untyped]) }
  def events; end

  # @return [String] ID of the workflow, extracted from the first event.
  sig { returns(String) }
  def workflow_id; end

  # Convert to history JSON.
  #
  # @return [String] JSON string.
  sig { returns(String) }
  def to_history_json; end

  # Compare history.
  #
  # @param other [WorkflowHistory] Other history.
  # @return [Boolean] True if equal.
  sig { params(other: Temporalio::WorkflowHistory).returns(T::Boolean) }
  def ==(other); end
end

# Metric for recording values. This class is effectively abstract.
class Temporalio::Metric
  # Record a value for the metric.
  #
  # @param value [Numeric] Value to record.
  # @param additional_attributes [Hash{String, Symbol => String, Integer, Float, Boolean}, nil] Additional attributes.
  sig do
    params(
      value: Numeric,
      additional_attributes: T.nilable(T::Hash[T.any(String, Symbol), T.any(String, Integer, Float, T::Boolean)])
    ).void
  end
  def record(value, additional_attributes: nil); end

  # Create a copy of this metric but with the given additional attributes.
  #
  # @param additional_attributes [Hash{String, Symbol => String, Integer, Float, Boolean}] Attributes to set.
  # @return [Metric] Copy of this metric with the additional attributes.
  sig do
    params(
      additional_attributes: T::Hash[T.any(String, Symbol), T.any(String, Integer, Float, T::Boolean)]
    ).returns(Temporalio::Metric)
  end
  def with_additional_attributes(additional_attributes); end

  # @return [:counter, :histogram, :gauge] Metric type.
  sig { returns(Symbol) }
  def metric_type; end

  # @return [String] Metric name.
  sig { returns(String) }
  def name; end

  # @return [String, nil] Metric description.
  sig { returns(T.nilable(String)) }
  def description; end

  # @return [String, nil] Metric unit.
  sig { returns(T.nilable(String)) }
  def unit; end

  # @return [:integer, :float, :duration] Metric value type.
  sig { returns(Symbol) }
  def value_type; end
end

# Meter for creating metrics to record values on.
class Temporalio::Metric::Meter
  # @return [Meter] A no-op instance of {Meter}.
  sig { returns(Temporalio::Metric::Meter) }
  def self.null; end

  # Create a new metric.
  #
  # @param metric_type [:counter, :histogram, :gauge] Metric type.
  # @param name [String] Metric name.
  # @param description [String, nil] Metric description.
  # @param unit [String, nil] Metric unit.
  # @param value_type [:integer, :float, :duration] Metric value type.
  # @return [Metric] Created metric.
  sig do
    params(
      metric_type: Symbol,
      name: String,
      description: T.nilable(String),
      unit: T.nilable(String),
      value_type: Symbol
    ).returns(Temporalio::Metric)
  end
  def create_metric(metric_type, name, description: nil, unit: nil, value_type: :integer); end

  # Create a copy of this meter but with the given additional attributes.
  #
  # @param additional_attributes [Hash{String, Symbol => String, Integer, Float, Boolean}] Attributes to set.
  # @return [Meter] Copy of this meter with the additional attributes.
  sig do
    params(
      additional_attributes: T::Hash[T.any(String, Symbol), T.any(String, Integer, Float, T::Boolean)]
    ).returns(Temporalio::Metric::Meter)
  end
  def with_additional_attributes(additional_attributes); end
end

# Logger that appends scoped values to log messages.
class Temporalio::ScopedLogger < ::SimpleDelegator
  sig { params(logger: ::Logger).void }
  def initialize(logger); end

  # @return [Proc, nil] Getter for scoped values.
  sig { returns(T.nilable(Proc)) }
  def scoped_values_getter; end

  # @param value [Proc, nil] Setter for scoped values getter.
  sig { params(value: T.nilable(Proc)).void }
  def scoped_values_getter=(value); end

  # @return [Boolean] Whether the scoped value appending is disabled.
  sig { returns(T::Boolean) }
  def disable_scoped_values; end

  # @param value [Boolean] Whether to disable scoped value appending.
  sig { params(value: T::Boolean).void }
  def disable_scoped_values=(value); end

  sig { params(severity: T.untyped, message: T.untyped, progname: T.untyped).void }
  def add(severity, message = nil, progname = nil); end

  sig { params(severity: T.untyped, message: T.untyped, progname: T.untyped).void }
  def log(severity, message = nil, progname = nil); end

  sig { params(progname: T.untyped, blk: T.untyped).void }
  def debug(progname = nil, &blk); end

  sig { params(progname: T.untyped, blk: T.untyped).void }
  def info(progname = nil, &blk); end

  sig { params(progname: T.untyped, blk: T.untyped).void }
  def warn(progname = nil, &blk); end

  sig { params(progname: T.untyped, blk: T.untyped).void }
  def error(progname = nil, &blk); end

  sig { params(progname: T.untyped, blk: T.untyped).void }
  def fatal(progname = nil, &blk); end

  sig { params(progname: T.untyped, blk: T.untyped).void }
  def unknown(progname = nil, &blk); end
end

# Scoped log message wrapping original log message.
class Temporalio::ScopedLogger::LogMessage
  sig { params(message: Object, scoped_values: Object).void }
  def initialize(message, scoped_values); end

  # @return [Object] Original log message.
  sig { returns(Object) }
  def message; end

  # @return [Object] Scoped values.
  sig { returns(Object) }
  def scoped_values; end

  # @return [String] Message with scoped values appended.
  sig { returns(String) }
  def inspect; end
end

# How already-in-use workflow IDs are handled on start.
module Temporalio::WorkflowIDReusePolicy
  # Allow starting a workflow execution using the same workflow ID.
  ALLOW_DUPLICATE = T.let(T.unsafe(nil), Integer)

  # Allow starting a workflow execution using the same workflow ID, only when the last execution's final state is one
  # of terminated, canceled, timed out, or failed.
  ALLOW_DUPLICATE_FAILED_ONLY = T.let(T.unsafe(nil), Integer)

  # Do not permit re-use of the workflow ID for this workflow.
  REJECT_DUPLICATE = T.let(T.unsafe(nil), Integer)

  # @deprecated Use {WorkflowIDConflictPolicy::TERMINATE_EXISTING} instead.
  TERMINATE_IF_RUNNING = T.let(T.unsafe(nil), Integer)
end

# How already-running workflows of the same ID are handled on start.
module Temporalio::WorkflowIDConflictPolicy
  # Unset.
  UNSPECIFIED = T.let(T.unsafe(nil), Integer)

  # Don't start a new workflow, instead fail with already-started error.
  FAIL = T.let(T.unsafe(nil), Integer)

  # Don't start a new workflow, instead return a workflow handle for the running workflow.
  USE_EXISTING = T.let(T.unsafe(nil), Integer)

  # Terminate the running workflow before starting a new one.
  TERMINATE_EXISTING = T.let(T.unsafe(nil), Integer)
end

# Versioning behavior for continue-as-new.
module Temporalio::ContinueAsNewVersioningBehavior
  # Unspecified. Follow existing continue-as-new inheritance semantics.
  UNSPECIFIED = T.let(T.unsafe(nil), Integer)

  # Start the new run with AutoUpgrade behavior.
  AUTO_UPGRADE = T.let(T.unsafe(nil), Integer)
end

# Specifies why the server suggests continue-as-new.
module Temporalio::SuggestContinueAsNewReason
  # Unspecified.
  UNSPECIFIED = T.let(T.unsafe(nil), Integer)

  # Workflow History size is getting too large.
  HISTORY_SIZE_TOO_LARGE = T.let(T.unsafe(nil), Integer)

  # Workflow History event count is getting too large.
  TOO_MANY_HISTORY_EVENTS = T.let(T.unsafe(nil), Integer)

  # Workflow's count of completed plus in-flight updates is too large.
  TOO_MANY_UPDATES = T.let(T.unsafe(nil), Integer)
end

# Specifies when a workflow might move from a worker of one Build Id to another.
module Temporalio::VersioningBehavior
  # Unspecified versioning behavior.
  UNSPECIFIED = T.let(T.unsafe(nil), Integer)

  # The workflow will be pinned to the current Build ID unless manually moved.
  PINNED = T.let(T.unsafe(nil), Integer)

  # The workflow will automatically move to the latest version when the next task is dispatched.
  AUTO_UPGRADE = T.let(T.unsafe(nil), Integer)
end

class Temporalio::Client
  # Create a client from an existing connection. Most users will prefer {connect} instead.
  #
  # @param connection [Connection] Existing connection to create a client from.
  # @param namespace [String] Namespace to use for client calls.
  # @param data_converter [Converters::DataConverter] Data converter to use for all data conversions to/from payloads.
  # @param plugins [Array<Plugin>] Plugins to use for configuring clients.
  # @param interceptors [Array<Interceptor>] Set of interceptors that are chained together to allow intercepting of
  #   client calls.
  # @param logger [Logger] Logger to use for this client and any workers made from this client.
  # @param default_workflow_query_reject_condition [WorkflowQueryRejectCondition, nil] Default rejection condition for
  #   workflow queries if not set during query.
  sig do
    params(
      connection: Temporalio::Client::Connection,
      namespace: String,
      data_converter: Temporalio::Converters::DataConverter,
      plugins: T::Array[Temporalio::Client::Plugin],
      interceptors: T::Array[Temporalio::Client::Interceptor],
      logger: ::Logger,
      default_workflow_query_reject_condition: T.nilable(Integer)
    ).void
  end
  def initialize(
    connection:,
    namespace:,
    data_converter: T.unsafe(nil),
    plugins: T.unsafe(nil),
    interceptors: T.unsafe(nil),
    logger: T.unsafe(nil),
    default_workflow_query_reject_condition: T.unsafe(nil)
  ); end

  # @return [Options] Frozen options for this client which has the same attributes as {initialize}.
  sig { returns(Temporalio::Client::Options) }
  def options; end

  # @return [Connection] Underlying connection for this client.
  sig { returns(Temporalio::Client::Connection) }
  def connection; end

  # @return [String] Namespace used in calls by this client.
  sig { returns(String) }
  def namespace; end

  # @return [DataConverter] Data converter used by this client.
  sig { returns(Temporalio::Converters::DataConverter) }
  def data_converter; end

  # @return [Connection::WorkflowService] Raw gRPC workflow service.
  sig { returns(Temporalio::Client::Connection::WorkflowService) }
  def workflow_service; end

  # @return [Connection::OperatorService] Raw gRPC operator service.
  sig { returns(Temporalio::Client::Connection::OperatorService) }
  def operator_service; end

  # Start a workflow and return its handle.
  #
  # @param workflow [Class<Workflow::Definition>, Symbol, String] Workflow definition class or workflow name.
  # @param args [Array<Object>] Arguments to the workflow.
  # @param id [String] Unique identifier for the workflow execution.
  # @param task_queue [String] Task queue to run the workflow on.
  # @param static_summary [String, nil] Fixed single-line summary for this workflow execution.
  # @param static_details [String, nil] Fixed details for this workflow execution.
  # @param execution_timeout [Float, Integer, nil] Total workflow execution timeout including retries and continue as new.
  # @param run_timeout [Float, Integer, nil] Timeout of a single workflow run.
  # @param task_timeout [Float, Integer, nil] Timeout of a single workflow task.
  # @param id_reuse_policy [WorkflowIDReusePolicy] How already-existing IDs are treated.
  # @param id_conflict_policy [WorkflowIDConflictPolicy] How already-running workflows of the same ID are treated.
  # @param retry_policy [RetryPolicy, nil] Retry policy for the workflow.
  # @param cron_schedule [String, nil] Cron schedule.
  # @param memo [Hash{String, Symbol => Object}, nil] Memo for the workflow.
  # @param search_attributes [SearchAttributes, nil] Search attributes for the workflow.
  # @param start_delay [Float, Integer, nil] Amount of time to wait before starting the workflow.
  # @param request_eager_start [Boolean] Potentially reduce the latency to start this workflow.
  # @param versioning_override [VersioningOverride, nil] Override the version of the workflow.
  # @param priority [Priority] Priority for the workflow.
  # @param arg_hints [Array<Object>, nil] Overrides converter hints for arguments.
  # @param result_hint [Object, nil] Overrides converter hint for result.
  # @param rpc_options [RPCOptions, nil] Advanced RPC options.
  # @return [WorkflowHandle] A workflow handle to the started workflow.
  sig do
    params(
      workflow: T.any(T.class_of(Temporalio::Workflow::Definition), Temporalio::Workflow::Definition::Info, Symbol, String),
      args: T.nilable(Object),
      id: String,
      task_queue: String,
      static_summary: T.nilable(String),
      static_details: T.nilable(String),
      execution_timeout: T.nilable(T.any(Integer, Float)),
      run_timeout: T.nilable(T.any(Integer, Float)),
      task_timeout: T.nilable(T.any(Integer, Float)),
      id_reuse_policy: Integer,
      id_conflict_policy: Integer,
      retry_policy: T.nilable(Temporalio::RetryPolicy),
      cron_schedule: T.nilable(String),
      memo: T.nilable(T::Hash[T.any(String, Symbol), T.nilable(Object)]),
      search_attributes: T.nilable(Temporalio::SearchAttributes),
      start_delay: T.nilable(T.any(Integer, Float)),
      request_eager_start: T::Boolean,
      versioning_override: T.nilable(Temporalio::VersioningOverride),
      priority: Temporalio::Priority,
      arg_hints: T.nilable(T::Array[Object]),
      result_hint: T.nilable(Object),
      rpc_options: T.nilable(Temporalio::Client::RPCOptions)
    ).returns(Temporalio::Client::WorkflowHandle)
  end
  def start_workflow(
    workflow,
    *args,
    id:,
    task_queue:,
    static_summary: T.unsafe(nil),
    static_details: T.unsafe(nil),
    execution_timeout: T.unsafe(nil),
    run_timeout: T.unsafe(nil),
    task_timeout: T.unsafe(nil),
    id_reuse_policy: T.unsafe(nil),
    id_conflict_policy: T.unsafe(nil),
    retry_policy: T.unsafe(nil),
    cron_schedule: T.unsafe(nil),
    memo: T.unsafe(nil),
    search_attributes: T.unsafe(nil),
    start_delay: T.unsafe(nil),
    request_eager_start: T.unsafe(nil),
    versioning_override: T.unsafe(nil),
    priority: T.unsafe(nil),
    arg_hints: T.unsafe(nil),
    result_hint: T.unsafe(nil),
    rpc_options: T.unsafe(nil)
  ); end

  # Start a workflow and wait for its result. This is a shortcut for {start_workflow} + {WorkflowHandle.result}.
  sig do
    params(
      workflow: T.any(T.class_of(Temporalio::Workflow::Definition), Temporalio::Workflow::Definition::Info, Symbol, String),
      args: T.nilable(Object),
      id: String,
      task_queue: String,
      static_summary: T.nilable(String),
      static_details: T.nilable(String),
      execution_timeout: T.nilable(T.any(Integer, Float)),
      run_timeout: T.nilable(T.any(Integer, Float)),
      task_timeout: T.nilable(T.any(Integer, Float)),
      id_reuse_policy: Integer,
      id_conflict_policy: Integer,
      retry_policy: T.nilable(Temporalio::RetryPolicy),
      cron_schedule: T.nilable(String),
      memo: T.nilable(T::Hash[T.any(String, Symbol), T.nilable(Object)]),
      search_attributes: T.nilable(Temporalio::SearchAttributes),
      start_delay: T.nilable(T.any(Integer, Float)),
      request_eager_start: T::Boolean,
      versioning_override: T.nilable(Temporalio::VersioningOverride),
      priority: Temporalio::Priority,
      arg_hints: T.nilable(T::Array[Object]),
      result_hint: T.nilable(Object),
      rpc_options: T.nilable(Temporalio::Client::RPCOptions)
    ).returns(T.nilable(Object))
  end
  def execute_workflow(
    workflow,
    *args,
    id:,
    task_queue:,
    static_summary: T.unsafe(nil),
    static_details: T.unsafe(nil),
    execution_timeout: T.unsafe(nil),
    run_timeout: T.unsafe(nil),
    task_timeout: T.unsafe(nil),
    id_reuse_policy: T.unsafe(nil),
    id_conflict_policy: T.unsafe(nil),
    retry_policy: T.unsafe(nil),
    cron_schedule: T.unsafe(nil),
    memo: T.unsafe(nil),
    search_attributes: T.unsafe(nil),
    start_delay: T.unsafe(nil),
    request_eager_start: T.unsafe(nil),
    versioning_override: T.unsafe(nil),
    priority: T.unsafe(nil),
    arg_hints: T.unsafe(nil),
    result_hint: T.unsafe(nil),
    rpc_options: T.unsafe(nil)
  ); end

  # Get a workflow handle to an existing workflow by its ID.
  #
  # @param workflow_id [String] Workflow ID to get a handle to.
  # @param run_id [String, nil] Run ID that will be used for all calls.
  # @param first_execution_run_id [String, nil] First execution run ID used for some calls.
  # @param result_hint [Object, nil] Converter hint for the workflow's result.
  # @return [WorkflowHandle] The workflow handle.
  sig do
    params(
      workflow_id: String,
      run_id: T.nilable(String),
      first_execution_run_id: T.nilable(String),
      result_hint: T.nilable(Object)
    ).returns(Temporalio::Client::WorkflowHandle)
  end
  def workflow_handle(workflow_id, run_id: T.unsafe(nil), first_execution_run_id: T.unsafe(nil), result_hint: T.unsafe(nil)); end

  # Start an update, possibly starting the workflow at the same time.
  sig do
    params(
      update: T.any(Temporalio::Workflow::Definition::Update, Symbol, String),
      args: T.nilable(Object),
      start_workflow_operation: Temporalio::Client::WithStartWorkflowOperation,
      wait_for_stage: Integer,
      id: String,
      arg_hints: T.nilable(T::Array[Object]),
      result_hint: T.nilable(Object),
      rpc_options: T.nilable(Temporalio::Client::RPCOptions)
    ).returns(Temporalio::Client::WorkflowUpdateHandle)
  end
  def start_update_with_start_workflow(
    update,
    *args,
    start_workflow_operation:,
    wait_for_stage:,
    id: T.unsafe(nil),
    arg_hints: T.unsafe(nil),
    result_hint: T.unsafe(nil),
    rpc_options: T.unsafe(nil)
  ); end

  # Start an update with start workflow and wait for update result.
  sig do
    params(
      update: T.any(Temporalio::Workflow::Definition::Update, Symbol, String),
      args: T.nilable(Object),
      start_workflow_operation: Temporalio::Client::WithStartWorkflowOperation,
      id: String,
      arg_hints: T.nilable(T::Array[Object]),
      result_hint: T.nilable(Object),
      rpc_options: T.nilable(Temporalio::Client::RPCOptions)
    ).returns(T.nilable(Object))
  end
  def execute_update_with_start_workflow(
    update,
    *args,
    start_workflow_operation:,
    id: T.unsafe(nil),
    arg_hints: T.unsafe(nil),
    result_hint: T.unsafe(nil),
    rpc_options: T.unsafe(nil)
  ); end

  # Send a signal, possibly starting the workflow at the same time.
  sig do
    params(
      signal: T.any(Temporalio::Workflow::Definition::Signal, Symbol, String),
      args: T.nilable(Object),
      start_workflow_operation: Temporalio::Client::WithStartWorkflowOperation,
      arg_hints: T.nilable(T::Array[Object]),
      rpc_options: T.nilable(Temporalio::Client::RPCOptions)
    ).returns(Temporalio::Client::WorkflowHandle)
  end
  def signal_with_start_workflow(
    signal,
    *args,
    start_workflow_operation:,
    arg_hints: T.unsafe(nil),
    rpc_options: T.unsafe(nil)
  ); end

  # List workflows.
  #
  # @param query [String, nil] A Temporal visibility list filter.
  # @param rpc_options [RPCOptions, nil] Advanced RPC options.
  # @return [Enumerator<WorkflowExecution>] Enumerable workflow executions.
  sig do
    params(
      query: T.nilable(String),
      rpc_options: T.nilable(Temporalio::Client::RPCOptions)
    ).returns(T::Enumerator[Temporalio::Client::WorkflowExecution])
  end
  def list_workflows(query = T.unsafe(nil), rpc_options: T.unsafe(nil)); end

  # List workflows one page at a time.
  sig do
    params(
      query: T.nilable(String),
      page_size: T.nilable(Integer),
      next_page_token: T.nilable(String),
      rpc_options: T.nilable(Temporalio::Client::RPCOptions)
    ).returns(Temporalio::Client::ListWorkflowPage)
  end
  def list_workflow_page(query = T.unsafe(nil), page_size: T.unsafe(nil), next_page_token: T.unsafe(nil), rpc_options: T.unsafe(nil)); end

  # Count workflows.
  sig do
    params(
      query: T.nilable(String),
      rpc_options: T.nilable(Temporalio::Client::RPCOptions)
    ).returns(Temporalio::Client::WorkflowExecutionCount)
  end
  def count_workflows(query = T.unsafe(nil), rpc_options: T.unsafe(nil)); end

  # Create a schedule and return its handle.
  sig do
    params(
      id: String,
      schedule: Temporalio::Client::Schedule,
      trigger_immediately: T::Boolean,
      backfills: T::Array[Temporalio::Client::Schedule::Backfill],
      memo: T.nilable(T::Hash[String, T.nilable(Object)]),
      search_attributes: T.nilable(Temporalio::SearchAttributes),
      rpc_options: T.nilable(Temporalio::Client::RPCOptions)
    ).returns(Temporalio::Client::ScheduleHandle)
  end
  def create_schedule(
    id,
    schedule,
    trigger_immediately: T.unsafe(nil),
    backfills: T.unsafe(nil),
    memo: T.unsafe(nil),
    search_attributes: T.unsafe(nil),
    rpc_options: T.unsafe(nil)
  ); end

  # Get a schedule handle to an existing schedule for the given ID.
  sig { params(id: String).returns(Temporalio::Client::ScheduleHandle) }
  def schedule_handle(id); end

  # List schedules.
  sig do
    params(
      query: T.nilable(String),
      rpc_options: T.nilable(Temporalio::Client::RPCOptions)
    ).returns(T::Enumerator[Temporalio::Client::Schedule::List::Description])
  end
  def list_schedules(query = T.unsafe(nil), rpc_options: T.unsafe(nil)); end

  # Get an async activity handle.
  sig do
    params(
      task_token_or_id_reference: T.any(String, Temporalio::Client::ActivityIDReference)
    ).returns(Temporalio::Client::AsyncActivityHandle)
  end
  def async_activity_handle(task_token_or_id_reference); end

  class << self
    # Connect to Temporal server.
    sig do
      params(
        target_host: String,
        namespace: String,
        api_key: T.nilable(String),
        tls: T.nilable(T.any(T::Boolean, Temporalio::Client::Connection::TLSOptions)),
        data_converter: Temporalio::Converters::DataConverter,
        plugins: T::Array[Temporalio::Client::Plugin],
        interceptors: T::Array[Temporalio::Client::Interceptor],
        logger: ::Logger,
        default_workflow_query_reject_condition: T.nilable(Integer),
        rpc_metadata: T::Hash[String, String],
        rpc_retry: Temporalio::Client::Connection::RPCRetryOptions,
        identity: String,
        keep_alive: Temporalio::Client::Connection::KeepAliveOptions,
        http_connect_proxy: T.nilable(Temporalio::Client::Connection::HTTPConnectProxyOptions),
        runtime: Temporalio::Runtime,
        lazy_connect: T::Boolean
      ).returns(Temporalio::Client)
    end
    def connect(
      target_host,
      namespace,
      api_key: T.unsafe(nil),
      tls: T.unsafe(nil),
      data_converter: T.unsafe(nil),
      plugins: T.unsafe(nil),
      interceptors: T.unsafe(nil),
      logger: T.unsafe(nil),
      default_workflow_query_reject_condition: T.unsafe(nil),
      rpc_metadata: T.unsafe(nil),
      rpc_retry: T.unsafe(nil),
      identity: T.unsafe(nil),
      keep_alive: T.unsafe(nil),
      http_connect_proxy: T.unsafe(nil),
      runtime: T.unsafe(nil),
      lazy_connect: T.unsafe(nil)
    ); end
  end
end

# Options as returned from {Client#options}.
class Temporalio::Client::Options < ::Data
  sig { returns(Temporalio::Client::Connection) }
  def connection; end

  sig { returns(String) }
  def namespace; end

  sig { returns(Temporalio::Converters::DataConverter) }
  def data_converter; end

  sig { returns(T::Array[Temporalio::Client::Plugin]) }
  def plugins; end

  sig { returns(T::Array[Temporalio::Client::Interceptor]) }
  def interceptors; end

  sig { returns(::Logger) }
  def logger; end

  sig { returns(T.nilable(Integer)) }
  def default_workflow_query_reject_condition; end

  sig { returns(T::Hash[Symbol, T.untyped]) }
  def to_h; end

  sig { params(kwargs: T.untyped).returns(Temporalio::Client::Options) }
  def with(**kwargs); end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Client::Options) }
    def new(*args); end

    sig { params(args: T.untyped).returns(Temporalio::Client::Options) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end

# A page of workflow executions returned by {Client#list_workflow_page}.
class Temporalio::Client::ListWorkflowPage < ::Data
  # @return [Array<WorkflowExecution>] List of workflow executions in this page.
  sig { returns(T::Array[Temporalio::Client::WorkflowExecution]) }
  def executions; end

  # @return [String, nil] Token for the next page of results.
  sig { returns(T.nilable(String)) }
  def next_page_token; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Client::ListWorkflowPage) }
    def new(*args); end

    sig { params(args: T.untyped).returns(Temporalio::Client::ListWorkflowPage) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end

# Set of RPC options for RPC calls.
class Temporalio::Client::RPCOptions
  sig do
    params(
      metadata: T.nilable(T::Hash[String, String]),
      timeout: T.nilable(Float),
      cancellation: T.nilable(Temporalio::Cancellation),
      override_retry: T.nilable(T::Boolean)
    ).void
  end
  def initialize(metadata: T.unsafe(nil), timeout: T.unsafe(nil), cancellation: T.unsafe(nil), override_retry: T.unsafe(nil)); end

  # @return [Hash<String, String>, nil] Headers to include on the RPC call.
  sig { returns(T.nilable(T::Hash[String, String])) }
  def metadata; end

  sig { params(value: T.nilable(T::Hash[String, String])).void }
  def metadata=(value); end

  # @return [Float, nil] Number of seconds before timeout of the RPC call.
  sig { returns(T.nilable(Float)) }
  def timeout; end

  sig { params(value: T.nilable(Float)).void }
  def timeout=(value); end

  # @return [Cancellation, nil] Cancellation to use to potentially cancel the call.
  sig { returns(T.nilable(Temporalio::Cancellation)) }
  def cancellation; end

  sig { params(value: T.nilable(Temporalio::Cancellation)).void }
  def cancellation=(value); end

  # @return [Boolean, nil] Whether to override the default retry option.
  sig { returns(T.nilable(T::Boolean)) }
  def override_retry; end

  sig { params(value: T.nilable(T::Boolean)).void }
  def override_retry=(value); end
end

# Connection to Temporal server that is not namespace specific.
class Temporalio::Client::Connection
  # Connect to Temporal server.
  sig do
    params(
      target_host: String,
      api_key: T.nilable(String),
      tls: T.nilable(T.any(T::Boolean, Temporalio::Client::Connection::TLSOptions)),
      rpc_metadata: T::Hash[String, String],
      rpc_retry: Temporalio::Client::Connection::RPCRetryOptions,
      identity: String,
      keep_alive: Temporalio::Client::Connection::KeepAliveOptions,
      http_connect_proxy: T.nilable(Temporalio::Client::Connection::HTTPConnectProxyOptions),
      runtime: Temporalio::Runtime,
      lazy_connect: T::Boolean,
      around_connect: T.nilable(T.proc.params(arg0: Temporalio::Client::Connection::Options, arg1: T.proc.params(arg0: Temporalio::Client::Connection::Options).void).void)
    ).void
  end
  def initialize(
    target_host:,
    api_key: T.unsafe(nil),
    tls: T.unsafe(nil),
    rpc_metadata: T.unsafe(nil),
    rpc_retry: T.unsafe(nil),
    identity: T.unsafe(nil),
    keep_alive: T.unsafe(nil),
    http_connect_proxy: T.unsafe(nil),
    runtime: T.unsafe(nil),
    lazy_connect: T.unsafe(nil),
    around_connect: T.unsafe(nil)
  ); end

  # @return [Options] Frozen options for this client.
  sig { returns(Temporalio::Client::Connection::Options) }
  def options; end

  # @return [WorkflowService] Raw gRPC workflow service.
  sig { returns(T.untyped) }
  def workflow_service; end

  # @return [OperatorService] Raw gRPC operator service.
  sig { returns(T.untyped) }
  def operator_service; end

  # @return [CloudService] Raw gRPC cloud service.
  sig { returns(T.untyped) }
  def cloud_service; end

  # @return [String] Target host this connection is connected to.
  sig { returns(String) }
  def target_host; end

  # @return [String] Client identity.
  sig { returns(String) }
  def identity; end

  # @return [Boolean] Whether this connection is connected.
  sig { returns(T::Boolean) }
  def connected?; end

  # @return [String, nil] API key.
  sig { returns(T.nilable(String)) }
  def api_key; end

  # Set the API key for all future calls.
  sig { params(new_key: T.nilable(String)).void }
  def api_key=(new_key); end

  # @return [Hash<String, String>] RPC metadata (aka HTTP headers).
  sig { returns(T::Hash[String, String]) }
  def rpc_metadata; end

  # Set the RPC metadata (aka HTTP headers) for all future calls.
  sig { params(rpc_metadata: T::Hash[String, String]).void }
  def rpc_metadata=(rpc_metadata); end
end

# Options as returned from {Connection#options}.
class Temporalio::Client::Connection::Options < ::Data
  sig { returns(String) }
  def target_host; end

  sig { returns(T.nilable(String)) }
  def api_key; end

  sig { returns(T.nilable(T.any(T::Boolean, Temporalio::Client::Connection::TLSOptions))) }
  def tls; end

  sig { returns(T::Hash[String, String]) }
  def rpc_metadata; end

  sig { returns(Temporalio::Client::Connection::RPCRetryOptions) }
  def rpc_retry; end

  sig { returns(String) }
  def identity; end

  sig { returns(Temporalio::Client::Connection::KeepAliveOptions) }
  def keep_alive; end

  sig { returns(Temporalio::Client::Connection::HTTPConnectProxyOptions) }
  def http_connect_proxy; end

  sig { returns(Temporalio::Runtime) }
  def runtime; end

  sig { returns(T::Boolean) }
  def lazy_connect; end

  sig { returns(T::Hash[Symbol, T.untyped]) }
  def to_h; end

  sig { params(kwargs: T.untyped).returns(Temporalio::Client::Connection::Options) }
  def with(**kwargs); end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Client::Connection::Options) }
    def new(*args); end

    sig { params(args: T.untyped).returns(Temporalio::Client::Connection::Options) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end

# TLS options. All attributes are optional, and an empty options set just enables default TLS.
class Temporalio::Client::Connection::TLSOptions < ::Data
  sig do
    params(
      client_cert: T.nilable(String),
      client_private_key: T.nilable(String),
      server_root_ca_cert: T.nilable(String),
      domain: T.nilable(String)
    ).void
  end
  def initialize(client_cert: T.unsafe(nil), client_private_key: T.unsafe(nil), server_root_ca_cert: T.unsafe(nil), domain: T.unsafe(nil)); end

  # @return [String, nil] Client certificate for mTLS.
  sig { returns(T.nilable(String)) }
  def client_cert; end

  # @return [String, nil] Client private key for mTLS.
  sig { returns(T.nilable(String)) }
  def client_private_key; end

  # @return [String, nil] Root CA certificate to validate the server certificate against.
  sig { returns(T.nilable(String)) }
  def server_root_ca_cert; end

  # @return [String, nil] SNI override.
  sig { returns(T.nilable(String)) }
  def domain; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Client::Connection::TLSOptions) }
    def new(*args); end

    sig { params(args: T.untyped).returns(Temporalio::Client::Connection::TLSOptions) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end

# Retry options for server calls.
class Temporalio::Client::Connection::RPCRetryOptions < ::Data
  sig do
    params(
      initial_interval: Float,
      randomization_factor: Float,
      multiplier: Float,
      max_interval: Float,
      max_elapsed_time: Float,
      max_retries: Integer
    ).void
  end
  def initialize(
    initial_interval: T.unsafe(nil),
    randomization_factor: T.unsafe(nil),
    multiplier: T.unsafe(nil),
    max_interval: T.unsafe(nil),
    max_elapsed_time: T.unsafe(nil),
    max_retries: T.unsafe(nil)
  ); end

  # @return [Float] Initial backoff interval, default 0.1.
  sig { returns(Float) }
  def initial_interval; end

  # @return [Float] Randomization jitter to add, default 0.2.
  sig { returns(Float) }
  def randomization_factor; end

  # @return [Float] Backoff multiplier, default 1.5.
  sig { returns(Float) }
  def multiplier; end

  # @return [Float] Maximum backoff interval, default 5.0.
  sig { returns(Float) }
  def max_interval; end

  # @return [Float] Maximum total time, default 10.0. Can use 0 for no max.
  sig { returns(Float) }
  def max_elapsed_time; end

  # @return [Integer] Maximum number of retries, default 10.
  sig { returns(Integer) }
  def max_retries; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Client::Connection::RPCRetryOptions) }
    def new(*args); end

    sig { params(args: T.untyped).returns(Temporalio::Client::Connection::RPCRetryOptions) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end

# Keep-alive options for client connections.
class Temporalio::Client::Connection::KeepAliveOptions < ::Data
  sig { params(interval: Float, timeout: Float).void }
  def initialize(interval: T.unsafe(nil), timeout: T.unsafe(nil)); end

  # @return [Float] Interval to send HTTP2 keep alive pings, default 30.0.
  sig { returns(Float) }
  def interval; end

  # @return [Float] Timeout that the keep alive must be responded to within, default 15.0.
  sig { returns(Float) }
  def timeout; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Client::Connection::KeepAliveOptions) }
    def new(*args); end

    sig { params(args: T.untyped).returns(Temporalio::Client::Connection::KeepAliveOptions) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end

# Options for HTTP CONNECT proxy for client connections.
class Temporalio::Client::Connection::HTTPConnectProxyOptions < ::Data
  # @return [String] Target for the HTTP CONNECT proxy.
  sig { returns(String) }
  def target_host; end

  # @return [String, nil] User for HTTP basic auth for the proxy.
  sig { returns(T.nilable(String)) }
  def basic_auth_user; end

  # @return [String, nil] Pass for HTTP basic auth for the proxy.
  sig { returns(T.nilable(String)) }
  def basic_auth_pass; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Client::Connection::HTTPConnectProxyOptions) }
    def new(*args); end

    sig { params(args: T.untyped).returns(Temporalio::Client::Connection::HTTPConnectProxyOptions) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end

# Base class for raw gRPC services.
class Temporalio::Client::Connection::Service
  sig { params(connection: Temporalio::Client::Connection, service: T.untyped).void }
  def initialize(connection, service); end

  protected

  sig do
    params(
      rpc: String,
      request_class: T.class_of(Object),
      response_class: T.class_of(Object),
      request: Object,
      rpc_options: T.nilable(Temporalio::Client::RPCOptions)
    ).returns(T.untyped)
  end
  def invoke_rpc(rpc:, request_class:, response_class:, request:, rpc_options:); end
end

# CloudService API.
class Temporalio::Client::Connection::CloudService < ::Temporalio::Client::Connection::Service
  sig { params(connection: Temporalio::Client::Connection).void }
  def initialize(connection); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def get_users(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def get_user(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def create_user(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def update_user(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def delete_user(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def set_user_namespace_access(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def get_async_operation(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def create_namespace(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def get_namespaces(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def get_namespace(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def update_namespace(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def rename_custom_search_attribute(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def delete_namespace(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def failover_namespace_region(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def add_namespace_region(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def delete_namespace_region(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def get_regions(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def get_region(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def get_api_keys(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def get_api_key(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def create_api_key(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def update_api_key(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def delete_api_key(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def get_nexus_endpoints(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def get_nexus_endpoint(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def create_nexus_endpoint(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def update_nexus_endpoint(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def delete_nexus_endpoint(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def get_user_groups(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def get_user_group(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def create_user_group(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def update_user_group(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def delete_user_group(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def set_user_group_namespace_access(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def add_user_group_member(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def remove_user_group_member(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def get_user_group_members(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def create_service_account(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def get_service_account(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def get_service_accounts(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def update_service_account(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def set_service_account_namespace_access(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def delete_service_account(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def get_usage(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def get_account(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def update_account(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def create_namespace_export_sink(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def get_namespace_export_sink(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def get_namespace_export_sinks(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def update_namespace_export_sink(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def delete_namespace_export_sink(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def validate_namespace_export_sink(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def update_namespace_tags(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def create_connectivity_rule(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def get_connectivity_rule(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def get_connectivity_rules(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def delete_connectivity_rule(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def validate_account_audit_log_sink(request, rpc_options: T.unsafe(nil)); end
end

# OperatorService API.
class Temporalio::Client::Connection::OperatorService < ::Temporalio::Client::Connection::Service
  sig { params(connection: Temporalio::Client::Connection).void }
  def initialize(connection); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def add_search_attributes(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def remove_search_attributes(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def list_search_attributes(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def delete_namespace(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def add_or_update_remote_cluster(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def remove_remote_cluster(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def list_clusters(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def get_nexus_endpoint(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def create_nexus_endpoint(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def update_nexus_endpoint(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def delete_nexus_endpoint(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def list_nexus_endpoints(request, rpc_options: T.unsafe(nil)); end
end

# WorkflowService API.
class Temporalio::Client::Connection::WorkflowService < ::Temporalio::Client::Connection::Service
  sig { params(connection: Temporalio::Client::Connection).void }
  def initialize(connection); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def register_namespace(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def describe_namespace(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def list_namespaces(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def update_namespace(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def deprecate_namespace(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def start_workflow_execution(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def execute_multi_operation(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def get_workflow_execution_history(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def get_workflow_execution_history_reverse(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def poll_workflow_task_queue(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def respond_workflow_task_completed(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def respond_workflow_task_failed(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def poll_activity_task_queue(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def record_activity_task_heartbeat(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def record_activity_task_heartbeat_by_id(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def respond_activity_task_completed(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def respond_activity_task_completed_by_id(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def respond_activity_task_failed(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def respond_activity_task_failed_by_id(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def respond_activity_task_canceled(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def respond_activity_task_canceled_by_id(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def request_cancel_workflow_execution(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def signal_workflow_execution(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def signal_with_start_workflow_execution(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def reset_workflow_execution(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def terminate_workflow_execution(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def delete_workflow_execution(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def list_open_workflow_executions(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def list_closed_workflow_executions(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def list_workflow_executions(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def list_archived_workflow_executions(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def scan_workflow_executions(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def count_workflow_executions(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def get_search_attributes(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def respond_query_task_completed(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def reset_sticky_task_queue(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def shutdown_worker(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def query_workflow(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def describe_workflow_execution(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def describe_task_queue(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def get_cluster_info(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def get_system_info(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def list_task_queue_partitions(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def create_schedule(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def describe_schedule(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def update_schedule(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def patch_schedule(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def list_schedule_matching_times(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def delete_schedule(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def list_schedules(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def count_schedules(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def update_worker_build_id_compatibility(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def get_worker_build_id_compatibility(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def update_worker_versioning_rules(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def get_worker_versioning_rules(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def get_worker_task_reachability(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def describe_deployment(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def describe_worker_deployment_version(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def list_deployments(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def get_deployment_reachability(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def get_current_deployment(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def set_current_deployment(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def set_worker_deployment_current_version(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def describe_worker_deployment(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def delete_worker_deployment(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def delete_worker_deployment_version(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def set_worker_deployment_ramping_version(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def list_worker_deployments(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def update_worker_deployment_version_metadata(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def set_worker_deployment_manager(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def update_workflow_execution(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def poll_workflow_execution_update(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def start_batch_operation(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def stop_batch_operation(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def describe_batch_operation(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def list_batch_operations(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def poll_nexus_task_queue(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def respond_nexus_task_completed(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def respond_nexus_task_failed(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def update_activity_options(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def update_workflow_execution_options(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def pause_activity(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def unpause_activity(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def reset_activity(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def create_workflow_rule(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def describe_workflow_rule(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def delete_workflow_rule(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def list_workflow_rules(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def trigger_workflow_rule(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def record_worker_heartbeat(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def list_workers(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def update_task_queue_config(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def fetch_worker_config(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def update_worker_config(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def describe_worker(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def pause_workflow_execution(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def unpause_workflow_execution(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def start_activity_execution(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def describe_activity_execution(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def poll_activity_execution(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def list_activity_executions(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def count_activity_executions(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def request_cancel_activity_execution(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def terminate_activity_execution(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def delete_activity_execution(request, rpc_options: T.unsafe(nil)); end
end

# TestService API.
class Temporalio::Client::Connection::TestService < ::Temporalio::Client::Connection::Service
  sig { params(connection: Temporalio::Client::Connection).void }
  def initialize(connection); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def lock_time_skipping(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def unlock_time_skipping(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def sleep(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def sleep_until(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def unlock_time_skipping_with_sleep(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: T.untyped, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(T.untyped) }
  def get_current_time(request, rpc_options: T.unsafe(nil)); end
end

# Handle for interacting with a workflow.
class Temporalio::Client::WorkflowHandle
  sig do
    params(
      client: Temporalio::Client,
      id: String,
      run_id: T.nilable(String),
      result_run_id: T.nilable(String),
      first_execution_run_id: T.nilable(String),
      result_hint: T.nilable(Object)
    ).void
  end
  def initialize(client:, id:, run_id:, result_run_id:, first_execution_run_id:, result_hint:); end

  # @return [String] ID for the workflow.
  sig { returns(String) }
  def id; end

  # @return [String, nil] Run ID.
  sig { returns(T.nilable(String)) }
  def run_id; end

  # @return [String, nil] Result run ID.
  sig { returns(T.nilable(String)) }
  def result_run_id; end

  # @return [String, nil] First execution run ID.
  sig { returns(T.nilable(String)) }
  def first_execution_run_id; end

  # @return [Object, nil] Result hint.
  sig { returns(T.nilable(Object)) }
  def result_hint; end

  # Wait for the result of the workflow.
  sig do
    params(
      follow_runs: T::Boolean,
      result_hint: T.nilable(Object),
      rpc_options: T.nilable(Temporalio::Client::RPCOptions)
    ).returns(T.nilable(Object))
  end
  def result(follow_runs: T.unsafe(nil), result_hint: T.unsafe(nil), rpc_options: T.unsafe(nil)); end

  # Get workflow details.
  sig do
    params(
      rpc_options: T.nilable(Temporalio::Client::RPCOptions)
    ).returns(Temporalio::Client::WorkflowExecution::Description)
  end
  def describe(rpc_options: T.unsafe(nil)); end

  # Get workflow history.
  sig do
    params(
      event_filter_type: Integer,
      rpc_options: T.nilable(Temporalio::Client::RPCOptions)
    ).returns(Temporalio::WorkflowHistory)
  end
  def fetch_history(event_filter_type: T.unsafe(nil), rpc_options: T.unsafe(nil)); end

  # Fetch an enumerator of history events for this workflow.
  sig do
    params(
      wait_new_event: T::Boolean,
      event_filter_type: Integer,
      skip_archival: T::Boolean,
      specific_run_id: T.nilable(String),
      rpc_options: T.nilable(Temporalio::Client::RPCOptions)
    ).returns(T::Enumerator[T.untyped])
  end
  def fetch_history_events(
    wait_new_event: T.unsafe(nil),
    event_filter_type: T.unsafe(nil),
    skip_archival: T.unsafe(nil),
    specific_run_id: T.unsafe(nil),
    rpc_options: T.unsafe(nil)
  ); end

  # Send a signal to the workflow.
  sig do
    params(
      signal: T.any(Temporalio::Workflow::Definition::Signal, Symbol, String),
      args: T.nilable(Object),
      arg_hints: T.nilable(T::Array[Object]),
      rpc_options: T.nilable(Temporalio::Client::RPCOptions)
    ).void
  end
  def signal(signal, *args, arg_hints: T.unsafe(nil), rpc_options: T.unsafe(nil)); end

  # Query the workflow.
  sig do
    params(
      query: T.any(Temporalio::Workflow::Definition::Query, Symbol, String),
      args: T.nilable(Object),
      reject_condition: T.nilable(Integer),
      arg_hints: T.nilable(T::Array[Object]),
      result_hint: T.nilable(Object),
      rpc_options: T.nilable(Temporalio::Client::RPCOptions)
    ).returns(T.nilable(Object))
  end
  def query(query, *args, reject_condition: T.unsafe(nil), arg_hints: T.unsafe(nil), result_hint: T.unsafe(nil), rpc_options: T.unsafe(nil)); end

  # Send an update request to the workflow and return a handle to it.
  sig do
    params(
      update: T.any(Temporalio::Workflow::Definition::Update, Symbol, String),
      args: T.nilable(Object),
      wait_for_stage: Integer,
      id: String,
      arg_hints: T.nilable(T::Array[Object]),
      result_hint: T.nilable(Object),
      rpc_options: T.nilable(Temporalio::Client::RPCOptions)
    ).returns(Temporalio::Client::WorkflowUpdateHandle)
  end
  def start_update(
    update,
    *args,
    wait_for_stage:,
    id: T.unsafe(nil),
    arg_hints: T.unsafe(nil),
    result_hint: T.unsafe(nil),
    rpc_options: T.unsafe(nil)
  ); end

  # Send an update request to the workflow and wait for it to complete.
  sig do
    params(
      update: T.any(Temporalio::Workflow::Definition::Update, Symbol, String),
      args: T.nilable(Object),
      id: String,
      arg_hints: T.nilable(T::Array[Object]),
      result_hint: T.nilable(Object),
      rpc_options: T.nilable(Temporalio::Client::RPCOptions)
    ).returns(T.nilable(Object))
  end
  def execute_update(update, *args, id: T.unsafe(nil), arg_hints: T.unsafe(nil), result_hint: T.unsafe(nil), rpc_options: T.unsafe(nil)); end

  # Get a handle for an update.
  sig do
    params(
      id: String,
      specific_run_id: T.nilable(String),
      result_hint: T.nilable(Object)
    ).returns(Temporalio::Client::WorkflowUpdateHandle)
  end
  def update_handle(id, specific_run_id: T.unsafe(nil), result_hint: T.unsafe(nil)); end

  # Cancel the workflow.
  sig { params(rpc_options: T.nilable(Temporalio::Client::RPCOptions)).void }
  def cancel(rpc_options: T.unsafe(nil)); end

  # Terminate the workflow.
  sig do
    params(
      reason: T.nilable(String),
      details: T::Array[T.nilable(Object)],
      rpc_options: T.nilable(Temporalio::Client::RPCOptions)
    ).void
  end
  def terminate(reason = T.unsafe(nil), details: T.unsafe(nil), rpc_options: T.unsafe(nil)); end
end

# Handle for a workflow update execution request.
class Temporalio::Client::WorkflowUpdateHandle
  sig do
    params(
      client: Temporalio::Client,
      id: String,
      workflow_id: String,
      workflow_run_id: T.nilable(String),
      known_outcome: T.untyped,
      result_hint: T.nilable(Object)
    ).void
  end
  def initialize(client:, id:, workflow_id:, workflow_run_id:, known_outcome:, result_hint:); end

  # @return [String] ID for the workflow update.
  sig { returns(String) }
  def id; end

  # @return [String] ID for the workflow.
  sig { returns(String) }
  def workflow_id; end

  # @return [String, nil] Run ID for the workflow.
  sig { returns(T.nilable(String)) }
  def workflow_run_id; end

  # @return [Object, nil] Result hint if one set when the handle was created.
  sig { returns(T.nilable(Object)) }
  def result_hint; end

  # @return [Boolean] True if the result is already known.
  sig { returns(T::Boolean) }
  def result_obtained?; end

  # Wait for and return the result of the update.
  sig do
    params(
      result_hint: T.nilable(Object),
      rpc_options: T.nilable(Temporalio::Client::RPCOptions)
    ).returns(T.nilable(Object))
  end
  def result(result_hint: T.unsafe(nil), rpc_options: T.unsafe(nil)); end
end

# Info for a single workflow execution run.
class Temporalio::Client::WorkflowExecution
  sig { params(raw_info: T.untyped, data_converter: Temporalio::Converters::DataConverter).void }
  def initialize(raw_info, data_converter); end

  # @return [Api::Workflow::V1::WorkflowExecutionInfo] Underlying protobuf info.
  sig { returns(T.untyped) }
  def raw_info; end

  sig { returns(T.nilable(Time)) }
  def close_time; end

  sig { returns(T.nilable(Time)) }
  def execution_time; end

  sig { returns(Integer) }
  def history_length; end

  sig { returns(String) }
  def id; end

  sig { returns(T.nilable(T::Hash[String, T.nilable(Object)])) }
  def memo; end

  sig { returns(T.nilable(String)) }
  def parent_id; end

  sig { returns(T.nilable(String)) }
  def parent_run_id; end

  sig { returns(String) }
  def run_id; end

  sig { returns(T.nilable(Temporalio::SearchAttributes)) }
  def search_attributes; end

  sig { returns(Time) }
  def start_time; end

  sig { returns(Integer) }
  def status; end

  sig { returns(String) }
  def task_queue; end

  sig { returns(String) }
  def workflow_type; end
end

# Description for a single workflow execution run.
class Temporalio::Client::WorkflowExecution::Description < ::Temporalio::Client::WorkflowExecution
  sig { params(raw_description: T.untyped, data_converter: Temporalio::Converters::DataConverter).void }
  def initialize(raw_description, data_converter); end

  sig { returns(T.untyped) }
  def raw_description; end

  sig { returns(T.nilable(String)) }
  def static_summary; end

  sig { returns(T.nilable(String)) }
  def static_details; end
end

# Representation of a count from a count workflows call.
class Temporalio::Client::WorkflowExecutionCount
  sig { params(count: Integer, groups: T::Array[Temporalio::Client::WorkflowExecutionCount::AggregationGroup]).void }
  def initialize(count, groups); end

  sig { returns(Integer) }
  def count; end

  sig { returns(T::Array[Temporalio::Client::WorkflowExecutionCount::AggregationGroup]) }
  def groups; end
end

# Aggregation group if the workflow count query had a group-by clause.
class Temporalio::Client::WorkflowExecutionCount::AggregationGroup
  sig { params(count: Integer, group_values: T::Array[T.nilable(Object)]).void }
  def initialize(count, group_values); end

  sig { returns(Integer) }
  def count; end

  sig { returns(T::Array[T.nilable(Object)]) }
  def group_values; end
end

# Status of a workflow execution.
module Temporalio::Client::WorkflowExecutionStatus
  RUNNING = T.let(T.unsafe(nil), Integer)
  COMPLETED = T.let(T.unsafe(nil), Integer)
  FAILED = T.let(T.unsafe(nil), Integer)
  CANCELED = T.let(T.unsafe(nil), Integer)
  TERMINATED = T.let(T.unsafe(nil), Integer)
  CONTINUED_AS_NEW = T.let(T.unsafe(nil), Integer)
  TIMED_OUT = T.let(T.unsafe(nil), Integer)
end

# Whether a query should be rejected in certain conditions.
module Temporalio::Client::WorkflowQueryRejectCondition
  NONE = T.let(T.unsafe(nil), Integer)
  NOT_OPEN = T.let(T.unsafe(nil), Integer)
  NOT_COMPLETED_CLEANLY = T.let(T.unsafe(nil), Integer)
end

# Stage to wait for workflow update to reach before returning.
module Temporalio::Client::WorkflowUpdateWaitStage
  ADMITTED = T.let(T.unsafe(nil), Integer)
  ACCEPTED = T.let(T.unsafe(nil), Integer)
  COMPLETED = T.let(T.unsafe(nil), Integer)
end

# Reference to an existing activity by its workflow ID, run ID, and activity ID.
class Temporalio::Client::ActivityIDReference
  sig { params(workflow_id: String, run_id: T.nilable(String), activity_id: String).void }
  def initialize(workflow_id:, run_id:, activity_id:); end

  # @return [String] ID for the workflow.
  sig { returns(String) }
  def workflow_id; end

  # @return [String, nil] Run ID for the workflow.
  sig { returns(T.nilable(String)) }
  def run_id; end

  # @return [String] ID for the activity.
  sig { returns(String) }
  def activity_id; end
end

# Handle representing an external activity for completion and heartbeat.
class Temporalio::Client::AsyncActivityHandle
  sig { params(client: Temporalio::Client, task_token: T.nilable(String), id_reference: T.nilable(Temporalio::Client::ActivityIDReference)).void }
  def initialize(client:, task_token:, id_reference:); end

  # @return [String, nil] Task token if created with a task token.
  sig { returns(T.nilable(String)) }
  def task_token; end

  # @return [ActivityIDReference, nil] Activity ID reference if created with one.
  sig { returns(T.nilable(Temporalio::Client::ActivityIDReference)) }
  def id_reference; end

  # Record a heartbeat for the activity.
  sig do
    params(
      details: T.nilable(Object),
      detail_hints: T.nilable(T::Array[Object]),
      rpc_options: T.nilable(Temporalio::Client::RPCOptions)
    ).void
  end
  def heartbeat(*details, detail_hints: T.unsafe(nil), rpc_options: T.unsafe(nil)); end

  # Complete the activity.
  sig do
    params(
      result: T.nilable(Object),
      result_hint: T.nilable(Object),
      rpc_options: T.nilable(Temporalio::Client::RPCOptions)
    ).void
  end
  def complete(result = T.unsafe(nil), result_hint: T.unsafe(nil), rpc_options: T.unsafe(nil)); end

  # Fail the activity.
  sig do
    params(
      error: Exception,
      last_heartbeat_details: T::Array[T.nilable(Object)],
      last_heartbeat_detail_hints: T.nilable(T::Array[Object]),
      rpc_options: T.nilable(Temporalio::Client::RPCOptions)
    ).void
  end
  def fail(error, last_heartbeat_details: T.unsafe(nil), last_heartbeat_detail_hints: T.unsafe(nil), rpc_options: T.unsafe(nil)); end

  # Report the activity as canceled.
  sig do
    params(
      details: T.nilable(Object),
      detail_hints: T.nilable(T::Array[Object]),
      rpc_options: T.nilable(Temporalio::Client::RPCOptions)
    ).void
  end
  def report_cancellation(*details, detail_hints: T.unsafe(nil), rpc_options: T.unsafe(nil)); end
end

# A schedule for periodically running an action.
class Temporalio::Client::Schedule < ::Data
  sig do
    params(
      action: Temporalio::Client::Schedule::Action,
      spec: Temporalio::Client::Schedule::Spec,
      policy: Temporalio::Client::Schedule::Policy,
      state: Temporalio::Client::Schedule::State
    ).void
  end
  def initialize(action:, spec:, policy: T.unsafe(nil), state: T.unsafe(nil)); end

  # @return [Action] Action taken when scheduled.
  sig { returns(Temporalio::Client::Schedule::Action) }
  def action; end

  # @return [Spec] When the action is taken.
  sig { returns(Temporalio::Client::Schedule::Spec) }
  def spec; end

  # @return [Policy] Schedule policies.
  sig { returns(Temporalio::Client::Schedule::Policy) }
  def policy; end

  # @return [State] State of the schedule.
  sig { returns(Temporalio::Client::Schedule::State) }
  def state; end

  sig { params(kwargs: T.untyped).returns(Temporalio::Client::Schedule) }
  def with(**kwargs); end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Client::Schedule) }
    def new(*args); end

    sig { params(args: T.untyped).returns(Temporalio::Client::Schedule) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end

# Base module mixed in by specific actions a schedule can take.
module Temporalio::Client::Schedule::Action; end

# Schedule action to start a workflow.
class Temporalio::Client::Schedule::Action::StartWorkflow < ::Data
  include Temporalio::Client::Schedule::Action

  sig { returns(T.any(T.class_of(Temporalio::Workflow::Definition), Temporalio::Workflow::Definition::Info, Symbol, String)) }
  def workflow; end

  sig { returns(T::Array[T.nilable(Object)]) }
  def args; end

  sig { returns(String) }
  def id; end

  sig { returns(String) }
  def task_queue; end

  sig { returns(T.nilable(String)) }
  def static_summary; end

  sig { returns(T.nilable(String)) }
  def static_details; end

  sig { returns(T.nilable(T.any(Integer, Float))) }
  def execution_timeout; end

  sig { returns(T.nilable(T.any(Integer, Float))) }
  def run_timeout; end

  sig { returns(T.nilable(T.any(Integer, Float))) }
  def task_timeout; end

  sig { returns(T.nilable(Temporalio::RetryPolicy)) }
  def retry_policy; end

  sig { returns(T.nilable(T::Hash[String, T.nilable(Object)])) }
  def memo; end

  sig { returns(T.nilable(Temporalio::SearchAttributes)) }
  def search_attributes; end

  sig { returns(T.nilable(T::Array[Object])) }
  def arg_hints; end

  sig { returns(T.nilable(T::Hash[String, T.nilable(Object)])) }
  def headers; end

  sig { params(kwargs: T.untyped).returns(Temporalio::Client::Schedule::Action::StartWorkflow) }
  def with(**kwargs); end

  class << self
    # Create start-workflow schedule action.
    sig do
      params(
        workflow: T.any(T.class_of(Temporalio::Workflow::Definition), Temporalio::Workflow::Definition::Info, Symbol, String),
        args: T.nilable(Object),
        id: String,
        task_queue: String,
        static_summary: T.nilable(String),
        static_details: T.nilable(String),
        execution_timeout: T.nilable(T.any(Integer, Float)),
        run_timeout: T.nilable(T.any(Integer, Float)),
        task_timeout: T.nilable(T.any(Integer, Float)),
        retry_policy: T.nilable(Temporalio::RetryPolicy),
        memo: T.nilable(T::Hash[String, T.nilable(Object)]),
        search_attributes: T.nilable(Temporalio::SearchAttributes),
        arg_hints: T.nilable(T::Array[Object]),
        headers: T.nilable(T::Hash[String, T.nilable(Object)])
      ).returns(Temporalio::Client::Schedule::Action::StartWorkflow)
    end
    def new(workflow, *args, id:, task_queue:, static_summary: T.unsafe(nil), static_details: T.unsafe(nil), execution_timeout: T.unsafe(nil), run_timeout: T.unsafe(nil), task_timeout: T.unsafe(nil), retry_policy: T.unsafe(nil), memo: T.unsafe(nil), search_attributes: T.unsafe(nil), arg_hints: T.unsafe(nil), headers: T.unsafe(nil)); end

    sig { params(args: T.untyped).returns(Temporalio::Client::Schedule::Action::StartWorkflow) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end

# Enumerate that controls what happens when a workflow would be started by a schedule but one is already running.
module Temporalio::Client::Schedule::OverlapPolicy
  SKIP = T.let(T.unsafe(nil), Integer)
  BUFFER_ONE = T.let(T.unsafe(nil), Integer)
  BUFFER_ALL = T.let(T.unsafe(nil), Integer)
  CANCEL_OTHER = T.let(T.unsafe(nil), Integer)
  TERMINATE_OTHER = T.let(T.unsafe(nil), Integer)
  ALLOW_ALL = T.let(T.unsafe(nil), Integer)
end

# Time period and policy for actions taken as if the time passed right now.
class Temporalio::Client::Schedule::Backfill < ::Data
  sig { params(start_at: Time, end_at: Time, overlap: T.nilable(Integer)).void }
  def initialize(start_at:, end_at:, overlap: T.unsafe(nil)); end

  sig { returns(Time) }
  def start_at; end

  sig { returns(Time) }
  def end_at; end

  sig { returns(T.nilable(Integer)) }
  def overlap; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Client::Schedule::Backfill) }
    def new(*args); end

    sig { params(args: T.untyped).returns(Temporalio::Client::Schedule::Backfill) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end

# Base module mixed in by specific action executions.
module Temporalio::Client::Schedule::ActionExecution; end

# Execution of a scheduled workflow start.
class Temporalio::Client::Schedule::ActionExecution::StartWorkflow < ::Data
  include Temporalio::Client::Schedule::ActionExecution

  sig { params(raw_execution: T.untyped).void }
  def initialize(raw_execution:); end

  sig { returns(String) }
  def workflow_id; end

  sig { returns(String) }
  def first_execution_run_id; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Client::Schedule::ActionExecution::StartWorkflow) }
    def new(*args); end

    sig { params(args: T.untyped).returns(Temporalio::Client::Schedule::ActionExecution::StartWorkflow) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end

# Information about when an action took place.
class Temporalio::Client::Schedule::ActionResult < ::Data
  sig { params(raw_result: T.untyped).void }
  def initialize(raw_result:); end

  sig { returns(Time) }
  def schedule_at; end

  sig { returns(Time) }
  def started_at; end

  sig { returns(Temporalio::Client::Schedule::ActionExecution) }
  def action; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Client::Schedule::ActionResult) }
    def new(*args); end

    sig { params(args: T.untyped).returns(Temporalio::Client::Schedule::ActionResult) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end

# Specification of the times scheduled actions may occur.
class Temporalio::Client::Schedule::Spec < ::Data
  sig do
    params(
      calendars: T::Array[Temporalio::Client::Schedule::Spec::Calendar],
      intervals: T::Array[Temporalio::Client::Schedule::Spec::Interval],
      cron_expressions: T::Array[String],
      skip: T::Array[Temporalio::Client::Schedule::Spec::Calendar],
      start_at: T.nilable(Time),
      end_at: T.nilable(Time),
      jitter: T.nilable(Float),
      time_zone_name: T.nilable(String)
    ).void
  end
  def initialize(
    calendars: T.unsafe(nil),
    intervals: T.unsafe(nil),
    cron_expressions: T.unsafe(nil),
    skip: T.unsafe(nil),
    start_at: T.unsafe(nil),
    end_at: T.unsafe(nil),
    jitter: T.unsafe(nil),
    time_zone_name: T.unsafe(nil)
  ); end

  sig { returns(T::Array[Temporalio::Client::Schedule::Spec::Calendar]) }
  def calendars; end

  sig { returns(T::Array[Temporalio::Client::Schedule::Spec::Interval]) }
  def intervals; end

  sig { returns(T::Array[String]) }
  def cron_expressions; end

  sig { returns(T::Array[Temporalio::Client::Schedule::Spec::Calendar]) }
  def skip; end

  sig { returns(T.nilable(Time)) }
  def start_at; end

  sig { returns(T.nilable(Time)) }
  def end_at; end

  sig { returns(T.nilable(Float)) }
  def jitter; end

  sig { returns(T.nilable(String)) }
  def time_zone_name; end

  sig { params(kwargs: T.untyped).returns(Temporalio::Client::Schedule::Spec) }
  def with(**kwargs); end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Client::Schedule::Spec) }
    def new(*args); end

    sig { params(args: T.untyped).returns(Temporalio::Client::Schedule::Spec) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end

# Specification relative to calendar time when to run an action.
class Temporalio::Client::Schedule::Spec::Calendar < ::Data
  sig do
    params(
      second: T::Array[Temporalio::Client::Schedule::Range],
      minute: T::Array[Temporalio::Client::Schedule::Range],
      hour: T::Array[Temporalio::Client::Schedule::Range],
      day_of_month: T::Array[Temporalio::Client::Schedule::Range],
      month: T::Array[Temporalio::Client::Schedule::Range],
      year: T::Array[Temporalio::Client::Schedule::Range],
      day_of_week: T::Array[Temporalio::Client::Schedule::Range],
      comment: T.nilable(String)
    ).void
  end
  def initialize(
    second: T.unsafe(nil),
    minute: T.unsafe(nil),
    hour: T.unsafe(nil),
    day_of_month: T.unsafe(nil),
    month: T.unsafe(nil),
    year: T.unsafe(nil),
    day_of_week: T.unsafe(nil),
    comment: T.unsafe(nil)
  ); end

  sig { returns(T::Array[Temporalio::Client::Schedule::Range]) }
  def second; end

  sig { returns(T::Array[Temporalio::Client::Schedule::Range]) }
  def minute; end

  sig { returns(T::Array[Temporalio::Client::Schedule::Range]) }
  def hour; end

  sig { returns(T::Array[Temporalio::Client::Schedule::Range]) }
  def day_of_month; end

  sig { returns(T::Array[Temporalio::Client::Schedule::Range]) }
  def month; end

  sig { returns(T::Array[Temporalio::Client::Schedule::Range]) }
  def year; end

  sig { returns(T::Array[Temporalio::Client::Schedule::Range]) }
  def day_of_week; end

  sig { returns(T.nilable(String)) }
  def comment; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Client::Schedule::Spec::Calendar) }
    def new(*args); end

    sig { params(args: T.untyped).returns(Temporalio::Client::Schedule::Spec::Calendar) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end

# Specification for scheduling on an interval.
class Temporalio::Client::Schedule::Spec::Interval < ::Data
  sig { params(every: T.any(Integer, Float), offset: T.nilable(T.any(Integer, Float))).void }
  def initialize(every:, offset: T.unsafe(nil)); end

  sig { returns(T.any(Integer, Float)) }
  def every; end

  sig { returns(T.nilable(T.any(Integer, Float))) }
  def offset; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Client::Schedule::Spec::Interval) }
    def new(*args); end

    sig { params(args: T.untyped).returns(Temporalio::Client::Schedule::Spec::Interval) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end

# Inclusive range for a schedule match value.
class Temporalio::Client::Schedule::Range < ::Data
  sig { returns(Integer) }
  def start; end

  sig { returns(Integer) }
  def finish; end

  sig { returns(Integer) }
  def step; end

  class << self
    sig { params(start: Integer, finish: Integer, step: Integer).returns(Temporalio::Client::Schedule::Range) }
    def new(start, finish = T.unsafe(nil), step = T.unsafe(nil)); end

    sig { params(args: T.untyped).returns(Temporalio::Client::Schedule::Range) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end

# Policies of a schedule.
class Temporalio::Client::Schedule::Policy < ::Data
  sig do
    params(
      overlap: Integer,
      catchup_window: T.any(Integer, Float),
      pause_on_failure: T::Boolean
    ).void
  end
  def initialize(overlap: T.unsafe(nil), catchup_window: T.unsafe(nil), pause_on_failure: T.unsafe(nil)); end

  sig { returns(Integer) }
  def overlap; end

  sig { returns(T.any(Integer, Float)) }
  def catchup_window; end

  sig { returns(T::Boolean) }
  def pause_on_failure; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Client::Schedule::Policy) }
    def new(*args); end

    sig { params(args: T.untyped).returns(Temporalio::Client::Schedule::Policy) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end

# State of a schedule.
class Temporalio::Client::Schedule::State < ::Data
  sig do
    params(
      note: T.nilable(String),
      paused: T::Boolean,
      limited_actions: T::Boolean,
      remaining_actions: Integer
    ).void
  end
  def initialize(note: T.unsafe(nil), paused: T.unsafe(nil), limited_actions: T.unsafe(nil), remaining_actions: T.unsafe(nil)); end

  sig { returns(T.nilable(String)) }
  def note; end

  sig { returns(T::Boolean) }
  def paused; end

  sig { returns(T::Boolean) }
  def limited_actions; end

  sig { returns(Integer) }
  def remaining_actions; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Client::Schedule::State) }
    def new(*args); end

    sig { params(args: T.untyped).returns(Temporalio::Client::Schedule::State) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end

# Description of a schedule.
class Temporalio::Client::Schedule::Description < ::Data
  sig { params(id: String, raw_description: T.untyped, data_converter: Temporalio::Converters::DataConverter).void }
  def initialize(id:, raw_description:, data_converter:); end

  sig { returns(String) }
  def id; end

  sig { returns(Temporalio::Client::Schedule) }
  def schedule; end

  sig { returns(Temporalio::Client::Schedule::Info) }
  def info; end

  sig { returns(T.untyped) }
  def raw_description; end

  sig { returns(T.nilable(T::Hash[String, T.nilable(Object)])) }
  def memo; end

  sig { returns(T.nilable(Temporalio::SearchAttributes)) }
  def search_attributes; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Client::Schedule::Description) }
    def new(*args); end

    sig { params(args: T.untyped).returns(Temporalio::Client::Schedule::Description) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end

# Information about a schedule.
class Temporalio::Client::Schedule::Info < ::Data
  sig { params(raw_info: T.untyped).void }
  def initialize(raw_info:); end

  sig { returns(Integer) }
  def num_actions; end

  sig { returns(Integer) }
  def num_actions_missed_catchup_window; end

  sig { returns(Integer) }
  def num_actions_skipped_overlap; end

  sig { returns(T::Array[Temporalio::Client::Schedule::ActionExecution]) }
  def running_actions; end

  sig { returns(T::Array[Temporalio::Client::Schedule::ActionResult]) }
  def recent_actions; end

  sig { returns(T::Array[Time]) }
  def next_action_times; end

  sig { returns(Time) }
  def created_at; end

  sig { returns(T.nilable(Time)) }
  def last_updated_at; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Client::Schedule::Info) }
    def new(*args); end

    sig { params(args: T.untyped).returns(Temporalio::Client::Schedule::Info) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end

# Result of an update callback for {ScheduleHandle.update}.
class Temporalio::Client::Schedule::Update < ::Data
  sig { params(schedule: Temporalio::Client::Schedule, search_attributes: T.nilable(Temporalio::SearchAttributes)).void }
  def initialize(schedule:, search_attributes: T.unsafe(nil)); end

  sig { returns(Temporalio::Client::Schedule) }
  def schedule; end

  sig { returns(T.nilable(Temporalio::SearchAttributes)) }
  def search_attributes; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Client::Schedule::Update) }
    def new(*args); end

    sig { params(args: T.untyped).returns(Temporalio::Client::Schedule::Update) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end

# Parameter for an update callback for {ScheduleHandle.update}.
class Temporalio::Client::Schedule::Update::Input < ::Data
  sig { returns(Temporalio::Client::Schedule::Description) }
  def description; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Client::Schedule::Update::Input) }
    def new(*args); end

    sig { params(args: T.untyped).returns(Temporalio::Client::Schedule::Update::Input) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end

module Temporalio::Client::Schedule::List; end

module Temporalio::Client::Schedule::List::Action; end

# Action to start a workflow on a listed schedule.
class Temporalio::Client::Schedule::List::Action::StartWorkflow < ::Data
  include Temporalio::Client::Schedule::List::Action

  sig { returns(String) }
  def workflow; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Client::Schedule::List::Action::StartWorkflow) }
    def new(*args); end

    sig { params(args: T.untyped).returns(Temporalio::Client::Schedule::List::Action::StartWorkflow) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end

# Description of a listed schedule.
class Temporalio::Client::Schedule::List::Description < ::Data
  sig { params(raw_entry: T.untyped, data_converter: Temporalio::Converters::DataConverter).void }
  def initialize(raw_entry:, data_converter:); end

  sig { returns(String) }
  def id; end

  sig { returns(Temporalio::Client::Schedule::List::Schedule) }
  def schedule; end

  sig { returns(Temporalio::Client::Schedule::List::Info) }
  def info; end

  sig { returns(T.untyped) }
  def raw_entry; end

  sig { returns(T.nilable(T::Hash[String, T.nilable(Object)])) }
  def memo; end

  sig { returns(T.nilable(Temporalio::SearchAttributes)) }
  def search_attributes; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Client::Schedule::List::Description) }
    def new(*args); end

    sig { params(args: T.untyped).returns(Temporalio::Client::Schedule::List::Description) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end

# Details for a listed schedule.
class Temporalio::Client::Schedule::List::Schedule < ::Data
  sig { params(raw_info: T.untyped).void }
  def initialize(raw_info:); end

  sig { returns(Temporalio::Client::Schedule::List::Action) }
  def action; end

  sig { returns(Temporalio::Client::Schedule::Spec) }
  def spec; end

  sig { returns(Temporalio::Client::Schedule::List::State) }
  def state; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Client::Schedule::List::Schedule) }
    def new(*args); end

    sig { params(args: T.untyped).returns(Temporalio::Client::Schedule::List::Schedule) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end

# Information about a listed schedule.
class Temporalio::Client::Schedule::List::Info < ::Data
  sig { params(raw_info: T.untyped).void }
  def initialize(raw_info:); end

  sig { returns(T::Array[Temporalio::Client::Schedule::ActionResult]) }
  def recent_actions; end

  sig { returns(T::Array[Time]) }
  def next_action_times; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Client::Schedule::List::Info) }
    def new(*args); end

    sig { params(args: T.untyped).returns(Temporalio::Client::Schedule::List::Info) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end

# State of a listed schedule.
class Temporalio::Client::Schedule::List::State < ::Data
  sig { params(raw_info: T.untyped).void }
  def initialize(raw_info:); end

  sig { returns(T.nilable(String)) }
  def note; end

  sig { returns(T::Boolean) }
  def paused; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Client::Schedule::List::State) }
    def new(*args); end

    sig { params(args: T.untyped).returns(Temporalio::Client::Schedule::List::State) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end

# Handle for interacting with a schedule.
class Temporalio::Client::ScheduleHandle
  sig { params(client: Temporalio::Client, id: String).void }
  def initialize(client:, id:); end

  # @return [String] ID of the schedule.
  sig { returns(String) }
  def id; end

  # Backfill the schedule.
  sig do
    params(
      backfills: Temporalio::Client::Schedule::Backfill,
      rpc_options: T.nilable(Temporalio::Client::RPCOptions)
    ).void
  end
  def backfill(*backfills, rpc_options: T.unsafe(nil)); end

  # Delete this schedule.
  sig { params(rpc_options: T.nilable(Temporalio::Client::RPCOptions)).void }
  def delete(rpc_options: T.unsafe(nil)); end

  # Fetch this schedule's description.
  sig { params(rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Client::Schedule::Description) }
  def describe(rpc_options: T.unsafe(nil)); end

  # Pause the schedule and set a note.
  sig { params(note: String, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).void }
  def pause(note: T.unsafe(nil), rpc_options: T.unsafe(nil)); end

  # Trigger an action on this schedule to happen immediately.
  sig { params(overlap: T.nilable(Integer), rpc_options: T.nilable(Temporalio::Client::RPCOptions)).void }
  def trigger(overlap: T.unsafe(nil), rpc_options: T.unsafe(nil)); end

  # Unpause the schedule and set a note.
  sig { params(note: String, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).void }
  def unpause(note: T.unsafe(nil), rpc_options: T.unsafe(nil)); end

  # Update a schedule using a callback to build the update from the description.
  sig do
    params(
      rpc_options: T.nilable(Temporalio::Client::RPCOptions),
      updater: T.proc.params(arg0: Temporalio::Client::Schedule::Update::Input).returns(T.nilable(Temporalio::Client::Schedule::Update))
    ).void
  end
  def update(rpc_options: T.unsafe(nil), &updater); end
end

# Start operation used by with-start workflow calls.
class Temporalio::Client::WithStartWorkflowOperation
  sig do
    params(
      workflow: T.any(T.class_of(Temporalio::Workflow::Definition), Temporalio::Workflow::Definition::Info, Symbol, String),
      args: T.nilable(Object),
      id: String,
      task_queue: String,
      static_summary: T.nilable(String),
      static_details: T.nilable(String),
      execution_timeout: T.nilable(T.any(Integer, Float)),
      run_timeout: T.nilable(T.any(Integer, Float)),
      task_timeout: T.nilable(T.any(Integer, Float)),
      id_reuse_policy: Integer,
      id_conflict_policy: Integer,
      retry_policy: T.nilable(Temporalio::RetryPolicy),
      cron_schedule: T.nilable(String),
      memo: T.nilable(T::Hash[T.any(String, Symbol), T.nilable(Object)]),
      search_attributes: T.nilable(Temporalio::SearchAttributes),
      start_delay: T.nilable(T.any(Integer, Float)),
      arg_hints: T.nilable(T::Array[Object]),
      result_hint: T.nilable(Object),
      headers: T.nilable(T::Hash[String, T.nilable(Object)])
    ).void
  end
  def initialize(
    workflow,
    *args,
    id:,
    task_queue:,
    static_summary: T.unsafe(nil),
    static_details: T.unsafe(nil),
    execution_timeout: T.unsafe(nil),
    run_timeout: T.unsafe(nil),
    task_timeout: T.unsafe(nil),
    id_reuse_policy: T.unsafe(nil),
    id_conflict_policy: T.unsafe(nil),
    retry_policy: T.unsafe(nil),
    cron_schedule: T.unsafe(nil),
    memo: T.unsafe(nil),
    search_attributes: T.unsafe(nil),
    start_delay: T.unsafe(nil),
    arg_hints: T.unsafe(nil),
    result_hint: T.unsafe(nil),
    headers: T.unsafe(nil)
  ); end

  # @return [Options] Options the operation was created with.
  sig { returns(Temporalio::Client::WithStartWorkflowOperation::Options) }
  def options; end

  sig { params(value: Temporalio::Client::WithStartWorkflowOperation::Options).void }
  def options=(value); end

  # Get the workflow handle, possibly waiting until set.
  sig { params(wait: T::Boolean).returns(T.nilable(Temporalio::Client::WorkflowHandle)) }
  def workflow_handle(wait: T.unsafe(nil)); end
end

# Options the operation was created with.
class Temporalio::Client::WithStartWorkflowOperation::Options < ::Data
  sig { returns(String) }
  def workflow; end

  sig { returns(T::Array[T.nilable(Object)]) }
  def args; end

  sig { returns(String) }
  def id; end

  sig { returns(String) }
  def task_queue; end

  sig { returns(T.nilable(String)) }
  def static_summary; end

  sig { returns(T.nilable(String)) }
  def static_details; end

  sig { returns(T.nilable(T.any(Integer, Float))) }
  def execution_timeout; end

  sig { returns(T.nilable(T.any(Integer, Float))) }
  def run_timeout; end

  sig { returns(T.nilable(T.any(Integer, Float))) }
  def task_timeout; end

  sig { returns(Integer) }
  def id_reuse_policy; end

  sig { returns(Integer) }
  def id_conflict_policy; end

  sig { returns(T.nilable(Temporalio::RetryPolicy)) }
  def retry_policy; end

  sig { returns(T.nilable(String)) }
  def cron_schedule; end

  sig { returns(T.nilable(T::Hash[T.any(String, Symbol), T.nilable(Object)])) }
  def memo; end

  sig { returns(T.nilable(Temporalio::SearchAttributes)) }
  def search_attributes; end

  sig { returns(T.nilable(T.any(Integer, Float))) }
  def start_delay; end

  sig { returns(T.nilable(T::Array[Object])) }
  def arg_hints; end

  sig { returns(T.nilable(Object)) }
  def result_hint; end

  sig { returns(T::Hash[String, T.nilable(Object)]) }
  def headers; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Client::WithStartWorkflowOperation::Options) }
    def new(*args); end

    sig { params(args: T.untyped).returns(Temporalio::Client::WithStartWorkflowOperation::Options) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end

# Mixin for intercepting clients.
module Temporalio::Client::Interceptor
  # Method called when intercepting a client.
  sig { params(next_interceptor: Temporalio::Client::Interceptor::Outbound).returns(Temporalio::Client::Interceptor::Outbound) }
  def intercept_client(next_interceptor); end
end

# Input for {Outbound.start_workflow}.
class Temporalio::Client::Interceptor::StartWorkflowInput < ::Data
  sig { returns(String) }
  def workflow; end

  sig { returns(T::Array[T.nilable(Object)]) }
  def args; end

  sig { returns(String) }
  def workflow_id; end

  sig { returns(String) }
  def task_queue; end

  sig { returns(T.nilable(String)) }
  def static_summary; end

  sig { returns(T.nilable(String)) }
  def static_details; end

  sig { returns(T.nilable(T.any(Integer, Float))) }
  def execution_timeout; end

  sig { returns(T.nilable(T.any(Integer, Float))) }
  def run_timeout; end

  sig { returns(T.nilable(T.any(Integer, Float))) }
  def task_timeout; end

  sig { returns(Integer) }
  def id_reuse_policy; end

  sig { returns(Integer) }
  def id_conflict_policy; end

  sig { returns(T.nilable(Temporalio::RetryPolicy)) }
  def retry_policy; end

  sig { returns(T.nilable(String)) }
  def cron_schedule; end

  sig { returns(T.nilable(T::Hash[T.any(String, Symbol), T.nilable(Object)])) }
  def memo; end

  sig { returns(T.nilable(Temporalio::SearchAttributes)) }
  def search_attributes; end

  sig { returns(T.nilable(T.any(Integer, Float))) }
  def start_delay; end

  sig { returns(T::Boolean) }
  def request_eager_start; end

  sig { returns(T.nilable(Temporalio::VersioningOverride)) }
  def versioning_override; end

  sig { returns(Temporalio::Priority) }
  def priority; end

  sig { returns(T.nilable(T::Array[Object])) }
  def arg_hints; end

  sig { returns(T.nilable(Object)) }
  def result_hint; end

  sig { returns(T::Hash[String, T.nilable(Object)]) }
  def headers; end

  sig { returns(T.nilable(Temporalio::Client::RPCOptions)) }
  def rpc_options; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Client::Interceptor::StartWorkflowInput) }
    def new(*args); end

    sig { params(args: T.untyped).returns(Temporalio::Client::Interceptor::StartWorkflowInput) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end

# Input for {Outbound.start_update_with_start_workflow}.
class Temporalio::Client::Interceptor::StartUpdateWithStartWorkflowInput < ::Data
  sig { returns(String) }
  def update_id; end

  sig { returns(String) }
  def update; end

  sig { returns(T::Array[T.nilable(Object)]) }
  def args; end

  sig { returns(Integer) }
  def wait_for_stage; end

  sig { returns(Temporalio::Client::WithStartWorkflowOperation) }
  def start_workflow_operation; end

  sig { returns(T.nilable(T::Array[Object])) }
  def arg_hints; end

  sig { returns(T.nilable(Object)) }
  def result_hint; end

  sig { returns(T::Hash[String, T.nilable(Object)]) }
  def headers; end

  sig { returns(T.nilable(Temporalio::Client::RPCOptions)) }
  def rpc_options; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Client::Interceptor::StartUpdateWithStartWorkflowInput) }
    def new(*args); end

    sig { params(args: T.untyped).returns(Temporalio::Client::Interceptor::StartUpdateWithStartWorkflowInput) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end

# Input for {Outbound.signal_with_start_workflow}.
class Temporalio::Client::Interceptor::SignalWithStartWorkflowInput < ::Data
  sig { returns(String) }
  def signal; end

  sig { returns(T::Array[T.nilable(Object)]) }
  def args; end

  sig { returns(Temporalio::Client::WithStartWorkflowOperation) }
  def start_workflow_operation; end

  sig { returns(T.nilable(T::Array[Object])) }
  def arg_hints; end

  sig { returns(T.nilable(Temporalio::Client::RPCOptions)) }
  def rpc_options; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Client::Interceptor::SignalWithStartWorkflowInput) }
    def new(*args); end

    sig { params(args: T.untyped).returns(Temporalio::Client::Interceptor::SignalWithStartWorkflowInput) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end

# Input for {Outbound.list_workflow_page}.
class Temporalio::Client::Interceptor::ListWorkflowPageInput < ::Data
  sig { returns(T.nilable(String)) }
  def query; end

  sig { returns(T.nilable(String)) }
  def next_page_token; end

  sig { returns(T.nilable(Integer)) }
  def page_size; end

  sig { returns(T.nilable(Temporalio::Client::RPCOptions)) }
  def rpc_options; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Client::Interceptor::ListWorkflowPageInput) }
    def new(*args); end

    sig { params(args: T.untyped).returns(Temporalio::Client::Interceptor::ListWorkflowPageInput) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end

# Input for {Outbound.count_workflows}.
class Temporalio::Client::Interceptor::CountWorkflowsInput < ::Data
  sig { returns(T.nilable(String)) }
  def query; end

  sig { returns(T.nilable(Temporalio::Client::RPCOptions)) }
  def rpc_options; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Client::Interceptor::CountWorkflowsInput) }
    def new(*args); end

    sig { params(args: T.untyped).returns(Temporalio::Client::Interceptor::CountWorkflowsInput) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end

# Input for {Outbound.describe_workflow}.
class Temporalio::Client::Interceptor::DescribeWorkflowInput < ::Data
  sig { returns(String) }
  def workflow_id; end

  sig { returns(T.nilable(String)) }
  def run_id; end

  sig { returns(T.nilable(Temporalio::Client::RPCOptions)) }
  def rpc_options; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Client::Interceptor::DescribeWorkflowInput) }
    def new(*args); end

    sig { params(args: T.untyped).returns(Temporalio::Client::Interceptor::DescribeWorkflowInput) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end

# Input for {Outbound.fetch_workflow_history_events}.
class Temporalio::Client::Interceptor::FetchWorkflowHistoryEventsInput < ::Data
  sig { returns(String) }
  def workflow_id; end

  sig { returns(T.nilable(String)) }
  def run_id; end

  sig { returns(T::Boolean) }
  def wait_new_event; end

  sig { returns(Integer) }
  def event_filter_type; end

  sig { returns(T::Boolean) }
  def skip_archival; end

  sig { returns(T.nilable(Temporalio::Client::RPCOptions)) }
  def rpc_options; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Client::Interceptor::FetchWorkflowHistoryEventsInput) }
    def new(*args); end

    sig { params(args: T.untyped).returns(Temporalio::Client::Interceptor::FetchWorkflowHistoryEventsInput) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end

# Input for {Outbound.signal_workflow}.
class Temporalio::Client::Interceptor::SignalWorkflowInput < ::Data
  sig { returns(String) }
  def workflow_id; end

  sig { returns(T.nilable(String)) }
  def run_id; end

  sig { returns(String) }
  def signal; end

  sig { returns(T::Array[T.nilable(Object)]) }
  def args; end

  sig { returns(T.nilable(T::Array[Object])) }
  def arg_hints; end

  sig { returns(T::Hash[String, T.nilable(Object)]) }
  def headers; end

  sig { returns(T.nilable(Temporalio::Client::RPCOptions)) }
  def rpc_options; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Client::Interceptor::SignalWorkflowInput) }
    def new(*args); end

    sig { params(args: T.untyped).returns(Temporalio::Client::Interceptor::SignalWorkflowInput) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end

# Input for {Outbound.query_workflow}.
class Temporalio::Client::Interceptor::QueryWorkflowInput < ::Data
  sig { returns(String) }
  def workflow_id; end

  sig { returns(T.nilable(String)) }
  def run_id; end

  sig { returns(String) }
  def query; end

  sig { returns(T::Array[T.nilable(Object)]) }
  def args; end

  sig { returns(T.nilable(Integer)) }
  def reject_condition; end

  sig { returns(T.nilable(T::Array[Object])) }
  def arg_hints; end

  sig { returns(T.nilable(Object)) }
  def result_hint; end

  sig { returns(T::Hash[String, T.nilable(Object)]) }
  def headers; end

  sig { returns(T.nilable(Temporalio::Client::RPCOptions)) }
  def rpc_options; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Client::Interceptor::QueryWorkflowInput) }
    def new(*args); end

    sig { params(args: T.untyped).returns(Temporalio::Client::Interceptor::QueryWorkflowInput) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end

# Input for {Outbound.start_workflow_update}.
class Temporalio::Client::Interceptor::StartWorkflowUpdateInput < ::Data
  sig { returns(String) }
  def workflow_id; end

  sig { returns(T.nilable(String)) }
  def run_id; end

  sig { returns(String) }
  def update_id; end

  sig { returns(String) }
  def update; end

  sig { returns(T::Array[T.nilable(Object)]) }
  def args; end

  sig { returns(Integer) }
  def wait_for_stage; end

  sig { returns(T.nilable(T::Array[Object])) }
  def arg_hints; end

  sig { returns(T.nilable(Object)) }
  def result_hint; end

  sig { returns(T::Hash[String, T.nilable(Object)]) }
  def headers; end

  sig { returns(T.nilable(Temporalio::Client::RPCOptions)) }
  def rpc_options; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Client::Interceptor::StartWorkflowUpdateInput) }
    def new(*args); end

    sig { params(args: T.untyped).returns(Temporalio::Client::Interceptor::StartWorkflowUpdateInput) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end

# Input for {Outbound.poll_workflow_update}.
class Temporalio::Client::Interceptor::PollWorkflowUpdateInput < ::Data
  sig { returns(String) }
  def workflow_id; end

  sig { returns(T.nilable(String)) }
  def run_id; end

  sig { returns(String) }
  def update_id; end

  sig { returns(T.nilable(Temporalio::Client::RPCOptions)) }
  def rpc_options; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Client::Interceptor::PollWorkflowUpdateInput) }
    def new(*args); end

    sig { params(args: T.untyped).returns(Temporalio::Client::Interceptor::PollWorkflowUpdateInput) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end

# Input for {Outbound.cancel_workflow}.
class Temporalio::Client::Interceptor::CancelWorkflowInput < ::Data
  sig { returns(String) }
  def workflow_id; end

  sig { returns(T.nilable(String)) }
  def run_id; end

  sig { returns(T.nilable(String)) }
  def first_execution_run_id; end

  sig { returns(T.nilable(Temporalio::Client::RPCOptions)) }
  def rpc_options; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Client::Interceptor::CancelWorkflowInput) }
    def new(*args); end

    sig { params(args: T.untyped).returns(Temporalio::Client::Interceptor::CancelWorkflowInput) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end

# Input for {Outbound.terminate_workflow}.
class Temporalio::Client::Interceptor::TerminateWorkflowInput < ::Data
  sig { returns(String) }
  def workflow_id; end

  sig { returns(T.nilable(String)) }
  def run_id; end

  sig { returns(T.nilable(String)) }
  def first_execution_run_id; end

  sig { returns(T.nilable(String)) }
  def reason; end

  sig { returns(T::Array[T.nilable(Object)]) }
  def details; end

  sig { returns(T.nilable(Temporalio::Client::RPCOptions)) }
  def rpc_options; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Client::Interceptor::TerminateWorkflowInput) }
    def new(*args); end

    sig { params(args: T.untyped).returns(Temporalio::Client::Interceptor::TerminateWorkflowInput) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end

# Input for {Outbound.create_schedule}.
class Temporalio::Client::Interceptor::CreateScheduleInput < ::Data
  sig { returns(String) }
  def id; end

  sig { returns(Temporalio::Client::Schedule) }
  def schedule; end

  sig { returns(T::Boolean) }
  def trigger_immediately; end

  sig { returns(T::Array[Temporalio::Client::Schedule::Backfill]) }
  def backfills; end

  sig { returns(T.nilable(T::Hash[T.any(String, Symbol), T.nilable(Object)])) }
  def memo; end

  sig { returns(T.nilable(Temporalio::SearchAttributes)) }
  def search_attributes; end

  sig { returns(T.nilable(Temporalio::Client::RPCOptions)) }
  def rpc_options; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Client::Interceptor::CreateScheduleInput) }
    def new(*args); end

    sig { params(args: T.untyped).returns(Temporalio::Client::Interceptor::CreateScheduleInput) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end

# Input for {Outbound.list_schedules}.
class Temporalio::Client::Interceptor::ListSchedulesInput < ::Data
  sig { returns(T.nilable(String)) }
  def query; end

  sig { returns(T.nilable(Temporalio::Client::RPCOptions)) }
  def rpc_options; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Client::Interceptor::ListSchedulesInput) }
    def new(*args); end

    sig { params(args: T.untyped).returns(Temporalio::Client::Interceptor::ListSchedulesInput) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end

# Input for {Outbound.backfill_schedule}.
class Temporalio::Client::Interceptor::BackfillScheduleInput < ::Data
  sig { returns(String) }
  def id; end

  sig { returns(T::Array[Temporalio::Client::Schedule::Backfill]) }
  def backfills; end

  sig { returns(T.nilable(Temporalio::Client::RPCOptions)) }
  def rpc_options; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Client::Interceptor::BackfillScheduleInput) }
    def new(*args); end

    sig { params(args: T.untyped).returns(Temporalio::Client::Interceptor::BackfillScheduleInput) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end

# Input for {Outbound.delete_schedule}.
class Temporalio::Client::Interceptor::DeleteScheduleInput < ::Data
  sig { returns(String) }
  def id; end

  sig { returns(T.nilable(Temporalio::Client::RPCOptions)) }
  def rpc_options; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Client::Interceptor::DeleteScheduleInput) }
    def new(*args); end

    sig { params(args: T.untyped).returns(Temporalio::Client::Interceptor::DeleteScheduleInput) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end

# Input for {Outbound.describe_schedule}.
class Temporalio::Client::Interceptor::DescribeScheduleInput < ::Data
  sig { returns(String) }
  def id; end

  sig { returns(T.nilable(Temporalio::Client::RPCOptions)) }
  def rpc_options; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Client::Interceptor::DescribeScheduleInput) }
    def new(*args); end

    sig { params(args: T.untyped).returns(Temporalio::Client::Interceptor::DescribeScheduleInput) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end

# Input for {Outbound.pause_schedule}.
class Temporalio::Client::Interceptor::PauseScheduleInput < ::Data
  sig { returns(String) }
  def id; end

  sig { returns(String) }
  def note; end

  sig { returns(T.nilable(Temporalio::Client::RPCOptions)) }
  def rpc_options; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Client::Interceptor::PauseScheduleInput) }
    def new(*args); end

    sig { params(args: T.untyped).returns(Temporalio::Client::Interceptor::PauseScheduleInput) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end

# Input for {Outbound.trigger_schedule}.
class Temporalio::Client::Interceptor::TriggerScheduleInput < ::Data
  sig { returns(String) }
  def id; end

  sig { returns(T.nilable(Integer)) }
  def overlap; end

  sig { returns(T.nilable(Temporalio::Client::RPCOptions)) }
  def rpc_options; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Client::Interceptor::TriggerScheduleInput) }
    def new(*args); end

    sig { params(args: T.untyped).returns(Temporalio::Client::Interceptor::TriggerScheduleInput) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end

# Input for {Outbound.unpause_schedule}.
class Temporalio::Client::Interceptor::UnpauseScheduleInput < ::Data
  sig { returns(String) }
  def id; end

  sig { returns(String) }
  def note; end

  sig { returns(T.nilable(Temporalio::Client::RPCOptions)) }
  def rpc_options; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Client::Interceptor::UnpauseScheduleInput) }
    def new(*args); end

    sig { params(args: T.untyped).returns(Temporalio::Client::Interceptor::UnpauseScheduleInput) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end

# Input for {Outbound.update_schedule}.
class Temporalio::Client::Interceptor::UpdateScheduleInput < ::Data
  sig { returns(String) }
  def id; end

  sig { returns(T.proc.params(arg0: Temporalio::Client::Schedule::Update::Input).returns(T.nilable(Temporalio::Client::Schedule::Update))) }
  def updater; end

  sig { returns(T.nilable(Temporalio::Client::RPCOptions)) }
  def rpc_options; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Client::Interceptor::UpdateScheduleInput) }
    def new(*args); end

    sig { params(args: T.untyped).returns(Temporalio::Client::Interceptor::UpdateScheduleInput) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end

# Input for {Outbound.heartbeat_async_activity}.
class Temporalio::Client::Interceptor::HeartbeatAsyncActivityInput < ::Data
  sig { returns(T.any(String, Temporalio::Client::ActivityIDReference)) }
  def task_token_or_id_reference; end

  sig { returns(T::Array[T.nilable(Object)]) }
  def details; end

  sig { returns(T.nilable(T::Array[Object])) }
  def detail_hints; end

  sig { returns(T.nilable(Temporalio::Client::RPCOptions)) }
  def rpc_options; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Client::Interceptor::HeartbeatAsyncActivityInput) }
    def new(*args); end

    sig { params(args: T.untyped).returns(Temporalio::Client::Interceptor::HeartbeatAsyncActivityInput) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end

# Input for {Outbound.complete_async_activity}.
class Temporalio::Client::Interceptor::CompleteAsyncActivityInput < ::Data
  sig { returns(T.any(String, Temporalio::Client::ActivityIDReference)) }
  def task_token_or_id_reference; end

  sig { returns(T.nilable(Object)) }
  def result; end

  sig { returns(T.nilable(Object)) }
  def result_hint; end

  sig { returns(T.nilable(Temporalio::Client::RPCOptions)) }
  def rpc_options; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Client::Interceptor::CompleteAsyncActivityInput) }
    def new(*args); end

    sig { params(args: T.untyped).returns(Temporalio::Client::Interceptor::CompleteAsyncActivityInput) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end

# Input for {Outbound.fail_async_activity}.
class Temporalio::Client::Interceptor::FailAsyncActivityInput < ::Data
  sig { returns(T.any(String, Temporalio::Client::ActivityIDReference)) }
  def task_token_or_id_reference; end

  sig { returns(Exception) }
  def error; end

  sig { returns(T::Array[T.nilable(Object)]) }
  def last_heartbeat_details; end

  sig { returns(T.nilable(T::Array[Object])) }
  def last_heartbeat_detail_hints; end

  sig { returns(T.nilable(Temporalio::Client::RPCOptions)) }
  def rpc_options; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Client::Interceptor::FailAsyncActivityInput) }
    def new(*args); end

    sig { params(args: T.untyped).returns(Temporalio::Client::Interceptor::FailAsyncActivityInput) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end

# Input for {Outbound.report_cancellation_async_activity}.
class Temporalio::Client::Interceptor::ReportCancellationAsyncActivityInput < ::Data
  sig { returns(T.any(String, Temporalio::Client::ActivityIDReference)) }
  def task_token_or_id_reference; end

  sig { returns(T::Array[T.nilable(Object)]) }
  def details; end

  sig { returns(T.nilable(T::Array[Object])) }
  def detail_hints; end

  sig { returns(T.nilable(Temporalio::Client::RPCOptions)) }
  def rpc_options; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Client::Interceptor::ReportCancellationAsyncActivityInput) }
    def new(*args); end

    sig { params(args: T.untyped).returns(Temporalio::Client::Interceptor::ReportCancellationAsyncActivityInput) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end

# Outbound interceptor for intercepting client calls.
class Temporalio::Client::Interceptor::Outbound
  sig { params(next_interceptor: Temporalio::Client::Interceptor::Outbound).void }
  def initialize(next_interceptor); end

  # @return [Outbound] Next interceptor in the chain.
  sig { returns(Temporalio::Client::Interceptor::Outbound) }
  def next_interceptor; end

  sig { params(input: Temporalio::Client::Interceptor::StartWorkflowInput).returns(Temporalio::Client::WorkflowHandle) }
  def start_workflow(input); end

  sig { params(input: Temporalio::Client::Interceptor::StartUpdateWithStartWorkflowInput).returns(Temporalio::Client::WorkflowUpdateHandle) }
  def start_update_with_start_workflow(input); end

  sig { params(input: Temporalio::Client::Interceptor::SignalWithStartWorkflowInput).returns(Temporalio::Client::WorkflowHandle) }
  def signal_with_start_workflow(input); end

  sig { params(input: Temporalio::Client::Interceptor::ListWorkflowPageInput).returns(Temporalio::Client::ListWorkflowPage) }
  def list_workflow_page(input); end

  sig { params(input: Temporalio::Client::Interceptor::CountWorkflowsInput).returns(Temporalio::Client::WorkflowExecutionCount) }
  def count_workflows(input); end

  sig { params(input: Temporalio::Client::Interceptor::DescribeWorkflowInput).returns(Temporalio::Client::WorkflowExecution::Description) }
  def describe_workflow(input); end

  sig { params(input: Temporalio::Client::Interceptor::FetchWorkflowHistoryEventsInput).returns(T::Enumerator[T.untyped]) }
  def fetch_workflow_history_events(input); end

  sig { params(input: Temporalio::Client::Interceptor::SignalWorkflowInput).void }
  def signal_workflow(input); end

  sig { params(input: Temporalio::Client::Interceptor::QueryWorkflowInput).returns(T.nilable(Object)) }
  def query_workflow(input); end

  sig { params(input: Temporalio::Client::Interceptor::StartWorkflowUpdateInput).returns(Temporalio::Client::WorkflowUpdateHandle) }
  def start_workflow_update(input); end

  sig { params(input: Temporalio::Client::Interceptor::PollWorkflowUpdateInput).returns(T.untyped) }
  def poll_workflow_update(input); end

  sig { params(input: Temporalio::Client::Interceptor::CancelWorkflowInput).void }
  def cancel_workflow(input); end

  sig { params(input: Temporalio::Client::Interceptor::TerminateWorkflowInput).void }
  def terminate_workflow(input); end

  sig { params(input: Temporalio::Client::Interceptor::CreateScheduleInput).returns(Temporalio::Client::ScheduleHandle) }
  def create_schedule(input); end

  sig { params(input: Temporalio::Client::Interceptor::ListSchedulesInput).returns(T::Enumerator[Temporalio::Client::WorkflowExecution]) }
  def list_schedules(input); end

  sig { params(input: Temporalio::Client::Interceptor::BackfillScheduleInput).void }
  def backfill_schedule(input); end

  sig { params(input: Temporalio::Client::Interceptor::DeleteScheduleInput).void }
  def delete_schedule(input); end

  sig { params(input: Temporalio::Client::Interceptor::DescribeScheduleInput).returns(Temporalio::Client::Schedule::Description) }
  def describe_schedule(input); end

  sig { params(input: Temporalio::Client::Interceptor::PauseScheduleInput).void }
  def pause_schedule(input); end

  sig { params(input: Temporalio::Client::Interceptor::TriggerScheduleInput).void }
  def trigger_schedule(input); end

  sig { params(input: Temporalio::Client::Interceptor::UnpauseScheduleInput).void }
  def unpause_schedule(input); end

  sig { params(input: Temporalio::Client::Interceptor::UpdateScheduleInput).void }
  def update_schedule(input); end

  sig { params(input: Temporalio::Client::Interceptor::HeartbeatAsyncActivityInput).void }
  def heartbeat_async_activity(input); end

  sig { params(input: Temporalio::Client::Interceptor::CompleteAsyncActivityInput).void }
  def complete_async_activity(input); end

  sig { params(input: Temporalio::Client::Interceptor::FailAsyncActivityInput).void }
  def fail_async_activity(input); end

  sig { params(input: Temporalio::Client::Interceptor::ReportCancellationAsyncActivityInput).void }
  def report_cancellation_async_activity(input); end
end

# Plugin mixin to include for configuring clients and/or intercepting connect calls.
module Temporalio::Client::Plugin
  # @return [String] Name of the plugin.
  sig { returns(String) }
  def name; end

  # Configure a client.
  sig { params(options: Temporalio::Client::Options).returns(Temporalio::Client::Options) }
  def configure_client(options); end

  # Connect a client.
  sig do
    params(
      options: Temporalio::Client::Connection::Options,
      next_call: T.proc.params(arg0: Temporalio::Client::Connection::Options).returns(Temporalio::Client::Connection)
    ).returns(Temporalio::Client::Connection)
  end
  def connect_client(options, next_call); end
end

class Temporalio::Worker
  extend T::Sig

  sig { returns(Options) }
  def options; end

  sig do
    params(
      client: Temporalio::Client,
      task_queue: String,
      activities: T::Array[T.any(Temporalio::Activity::Definition, T.class_of(Temporalio::Activity::Definition), Temporalio::Activity::Definition::Info)],
      workflows: T::Array[T.any(T.class_of(Temporalio::Workflow::Definition), Temporalio::Workflow::Definition::Info)],
      tuner: Temporalio::Worker::Tuner,
      activity_executors: T::Hash[Symbol, Temporalio::Worker::ActivityExecutor],
      workflow_executor: Temporalio::Worker::WorkflowExecutor,
      plugins: T::Array[Temporalio::Worker::Plugin],
      interceptors: T::Array[T.any(Temporalio::Worker::Interceptor::Activity, Temporalio::Worker::Interceptor::Workflow)],
      identity: T.nilable(String),
      logger: Logger,
      max_cached_workflows: Integer,
      max_concurrent_workflow_task_polls: Integer,
      nonsticky_to_sticky_poll_ratio: Float,
      max_concurrent_activity_task_polls: Integer,
      no_remote_activities: T::Boolean,
      sticky_queue_schedule_to_start_timeout: Float,
      max_heartbeat_throttle_interval: Float,
      default_heartbeat_throttle_interval: Float,
      max_activities_per_second: T.nilable(Float),
      max_task_queue_activities_per_second: T.nilable(Float),
      graceful_shutdown_period: Float,
      disable_eager_activity_execution: T::Boolean,
      illegal_workflow_calls: T::Hash[String, T.any(Symbol, T::Array[T.any(Symbol, Temporalio::Worker::IllegalWorkflowCallValidator)], Temporalio::Worker::IllegalWorkflowCallValidator)],
      workflow_failure_exception_types: T::Array[T.class_of(Exception)],
      workflow_payload_codec_thread_pool: T.nilable(Temporalio::Worker::ThreadPool),
      unsafe_workflow_io_enabled: T::Boolean,
      workflow_task_poller_behavior: Temporalio::Worker::PollerBehavior,
      activity_task_poller_behavior: Temporalio::Worker::PollerBehavior,
      deployment_options: Temporalio::Worker::DeploymentOptions,
      debug_mode: T::Boolean
    ).void
  end
  def initialize(
    client:,
    task_queue:,
    activities: T.unsafe(nil),
    workflows: T.unsafe(nil),
    tuner: T.unsafe(nil),
    activity_executors: T.unsafe(nil),
    workflow_executor: T.unsafe(nil),
    plugins: T.unsafe(nil),
    interceptors: T.unsafe(nil),
    identity: T.unsafe(nil),
    logger: T.unsafe(nil),
    max_cached_workflows: T.unsafe(nil),
    max_concurrent_workflow_task_polls: T.unsafe(nil),
    nonsticky_to_sticky_poll_ratio: T.unsafe(nil),
    max_concurrent_activity_task_polls: T.unsafe(nil),
    no_remote_activities: T.unsafe(nil),
    sticky_queue_schedule_to_start_timeout: T.unsafe(nil),
    max_heartbeat_throttle_interval: T.unsafe(nil),
    default_heartbeat_throttle_interval: T.unsafe(nil),
    max_activities_per_second: T.unsafe(nil),
    max_task_queue_activities_per_second: T.unsafe(nil),
    graceful_shutdown_period: T.unsafe(nil),
    disable_eager_activity_execution: T.unsafe(nil),
    illegal_workflow_calls: T.unsafe(nil),
    workflow_failure_exception_types: T.unsafe(nil),
    workflow_payload_codec_thread_pool: T.unsafe(nil),
    unsafe_workflow_io_enabled: T.unsafe(nil),
    workflow_task_poller_behavior: T.unsafe(nil),
    activity_task_poller_behavior: T.unsafe(nil),
    deployment_options: T.unsafe(nil),
    debug_mode: T.unsafe(nil)
  ); end

  sig { returns(String) }
  def task_queue; end

  sig { returns(Temporalio::Client) }
  def client; end

  sig { params(new_client: Temporalio::Client).void }
  def client=(new_client); end

  sig do
    type_parameters(:T)
      .params(
        cancellation: Temporalio::Cancellation,
        shutdown_signals: T::Array[T.any(String, Integer)],
        raise_in_block_on_shutdown: T.nilable(Exception),
        wait_block_complete: T::Boolean,
        block: T.nilable(T.proc.returns(T.type_parameter(:T)))
      ).returns(T.type_parameter(:T))
  end
  def run(
    cancellation: T.unsafe(nil),
    shutdown_signals: T.unsafe(nil),
    raise_in_block_on_shutdown: T.unsafe(nil),
    wait_block_complete: T.unsafe(nil),
    &block
  ); end

  class << self
    extend T::Sig

    sig { returns(String) }
    def default_build_id; end

    sig { returns(Temporalio::Worker::DeploymentOptions) }
    def default_deployment_options; end

    sig do
      type_parameters(:T)
        .params(
          workers: Temporalio::Worker,
          cancellation: Temporalio::Cancellation,
          shutdown_signals: T::Array[T.any(String, Integer)],
          raise_in_block_on_shutdown: T.nilable(Exception),
          wait_block_complete: T::Boolean,
          block: T.nilable(T.proc.returns(T.type_parameter(:T)))
        ).returns(T.type_parameter(:T))
    end
    def run_all(
      *workers,
      cancellation: T.unsafe(nil),
      shutdown_signals: T.unsafe(nil),
      raise_in_block_on_shutdown: T.unsafe(nil),
      wait_block_complete: T.unsafe(nil),
      &block
    ); end

    sig { returns(T::Hash[String, T.any(Symbol, T::Array[T.any(Symbol, IllegalWorkflowCallValidator)], IllegalWorkflowCallValidator)]) }
    def default_illegal_workflow_calls; end
  end
end

# ============================================================
# Temporalio::Worker::Options
# ============================================================

class Temporalio::Worker::Options < ::Data
  extend T::Sig

  sig { returns(Temporalio::Client) }
  def client; end

  sig { returns(String) }
  def task_queue; end

  sig { returns(T::Array[T.any(Temporalio::Activity::Definition, T.class_of(Temporalio::Activity::Definition), Temporalio::Activity::Definition::Info)]) }
  def activities; end

  sig { returns(T::Array[T.any(T.class_of(Temporalio::Workflow::Definition), Temporalio::Workflow::Definition::Info)]) }
  def workflows; end

  sig { returns(Temporalio::Worker::Tuner) }
  def tuner; end

  sig { returns(T::Hash[Symbol, Temporalio::Worker::ActivityExecutor]) }
  def activity_executors; end

  sig { returns(Temporalio::Worker::WorkflowExecutor) }
  def workflow_executor; end

  sig { returns(T::Array[Temporalio::Worker::Plugin]) }
  def plugins; end

  sig { returns(T::Array[T.any(Temporalio::Worker::Interceptor::Activity, Temporalio::Worker::Interceptor::Workflow)]) }
  def interceptors; end

  sig { returns(String) }
  def identity; end

  sig { returns(Logger) }
  def logger; end

  sig { returns(Integer) }
  def max_cached_workflows; end

  sig { returns(Integer) }
  def max_concurrent_workflow_task_polls; end

  sig { returns(Float) }
  def nonsticky_to_sticky_poll_ratio; end

  sig { returns(Integer) }
  def max_concurrent_activity_task_polls; end

  sig { returns(T::Boolean) }
  def no_remote_activities; end

  sig { returns(Float) }
  def sticky_queue_schedule_to_start_timeout; end

  sig { returns(Float) }
  def max_heartbeat_throttle_interval; end

  sig { returns(Float) }
  def default_heartbeat_throttle_interval; end

  sig { returns(T.nilable(Float)) }
  def max_activities_per_second; end

  sig { returns(T.nilable(Float)) }
  def max_task_queue_activities_per_second; end

  sig { returns(Float) }
  def graceful_shutdown_period; end

  sig { returns(T::Boolean) }
  def disable_eager_activity_execution; end

  sig { returns(T::Hash[String, T.any(Symbol, T::Array[T.any(Symbol, Temporalio::Worker::IllegalWorkflowCallValidator)], Temporalio::Worker::IllegalWorkflowCallValidator)]) }
  def illegal_workflow_calls; end

  sig { returns(T::Array[T.class_of(Exception)]) }
  def workflow_failure_exception_types; end

  sig { returns(T.nilable(Temporalio::Worker::ThreadPool)) }
  def workflow_payload_codec_thread_pool; end

  sig { returns(T::Boolean) }
  def unsafe_workflow_io_enabled; end

  sig { returns(Temporalio::Worker::PollerBehavior) }
  def workflow_task_poller_behavior; end

  sig { returns(Temporalio::Worker::PollerBehavior) }
  def activity_task_poller_behavior; end

  sig { returns(Temporalio::Worker::DeploymentOptions) }
  def deployment_options; end

  sig { returns(T::Boolean) }
  def debug_mode; end

  sig { params(kwargs: T.untyped).returns(Temporalio::Worker::Options) }
  def with(**kwargs); end
end

# ============================================================
# Temporalio::Worker::ActivityExecutor
# ============================================================

class Temporalio::Worker::ActivityExecutor
  extend T::Sig

  sig { returns(T::Hash[Symbol, Temporalio::Worker::ActivityExecutor]) }
  def self.defaults; end

  sig { params(defn: Temporalio::Activity::Definition::Info).void }
  def initialize_activity(defn); end

  sig { params(defn: Temporalio::Activity::Definition::Info, block: T.proc.void).void }
  def execute_activity(defn, &block); end

  sig { returns(T.nilable(Temporalio::Activity::Context)) }
  def activity_context; end

  sig { params(defn: Temporalio::Activity::Definition::Info, context: T.nilable(Temporalio::Activity::Context)).void }
  def set_activity_context(defn, context); end
end

# Activity executor for scheduling activities as fibers.
class Temporalio::Worker::ActivityExecutor::Fiber < Temporalio::Worker::ActivityExecutor
  extend T::Sig

  sig { returns(Temporalio::Worker::ActivityExecutor::Fiber) }
  def self.default; end

  sig { params(defn: Temporalio::Activity::Definition::Info).void }
  def initialize_activity(defn); end

  sig { params(defn: Temporalio::Activity::Definition::Info, block: T.proc.void).void }
  def execute_activity(defn, &block); end

  sig { returns(T.nilable(Temporalio::Activity::Context)) }
  def activity_context; end

  sig { params(defn: Temporalio::Activity::Definition::Info, context: T.nilable(Temporalio::Activity::Context)).void }
  def set_activity_context(defn, context); end
end

# Activity executor for scheduling activities in their own thread.
class Temporalio::Worker::ActivityExecutor::ThreadPool < ::Temporalio::Worker::ActivityExecutor
  extend T::Sig

  sig { returns(Temporalio::Worker::ActivityExecutor::ThreadPool) }
  def self.default; end

  sig { params(thread_pool: Temporalio::Worker::ThreadPool).void }
  def initialize(thread_pool = T.unsafe(nil)); end

  sig { params(defn: Temporalio::Activity::Definition::Info, block: T.proc.void).void }
  def execute_activity(defn, &block); end

  sig { returns(T.nilable(Temporalio::Activity::Context)) }
  def activity_context; end

  sig { params(defn: Temporalio::Activity::Definition::Info, context: T.nilable(Temporalio::Activity::Context)).void }
  def set_activity_context(defn, context); end
end

# ============================================================
# Temporalio::Worker::WorkflowExecutor
# ============================================================

class Temporalio::Worker::WorkflowExecutor
  extend T::Sig

  sig { void }
  def initialize; end
end

# Thread pool implementation of WorkflowExecutor.
class Temporalio::Worker::WorkflowExecutor::ThreadPool < ::Temporalio::Worker::WorkflowExecutor
  extend T::Sig

  sig { returns(Temporalio::Worker::WorkflowExecutor::ThreadPool) }
  def self.default; end

  sig { params(max_threads: Integer, thread_pool: Temporalio::Worker::ThreadPool).void }
  def initialize(max_threads: T.unsafe(nil), thread_pool: T.unsafe(nil)); end
end

# Error raised when a processing a workflow task takes more than the expected amount of time.
class Temporalio::Worker::WorkflowExecutor::ThreadPool::DeadlockError < ::Exception; end

# ============================================================
# Temporalio::Worker::Tuner
# ============================================================

class Temporalio::Worker::Tuner
  extend T::Sig

  sig { returns(SlotSupplier) }
  def workflow_slot_supplier; end

  sig { returns(SlotSupplier) }
  def activity_slot_supplier; end

  sig { returns(SlotSupplier) }
  def local_activity_slot_supplier; end

  sig { returns(T.nilable(Temporalio::Worker::ThreadPool)) }
  def custom_slot_supplier_thread_pool; end

  sig do
    params(
      workflow_slot_supplier: SlotSupplier,
      activity_slot_supplier: SlotSupplier,
      local_activity_slot_supplier: SlotSupplier,
      custom_slot_supplier_thread_pool: T.nilable(Temporalio::Worker::ThreadPool)
    ).void
  end
  def initialize(
    workflow_slot_supplier:,
    activity_slot_supplier:,
    local_activity_slot_supplier:,
    custom_slot_supplier_thread_pool: T.unsafe(nil)
  ); end

  class << self
    extend T::Sig

    sig do
      params(
        workflow_slots: Integer,
        activity_slots: Integer,
        local_activity_slots: Integer
      ).returns(Temporalio::Worker::Tuner)
    end
    def create_fixed(workflow_slots: T.unsafe(nil), activity_slots: T.unsafe(nil), local_activity_slots: T.unsafe(nil)); end

    sig do
      params(
        target_memory_usage: Float,
        target_cpu_usage: Float,
        workflow_options: ResourceBasedSlotOptions,
        activity_options: ResourceBasedSlotOptions,
        local_activity_options: ResourceBasedSlotOptions
      ).returns(Temporalio::Worker::Tuner)
    end
    def create_resource_based(
      target_memory_usage:,
      target_cpu_usage:,
      workflow_options: T.unsafe(nil),
      activity_options: T.unsafe(nil),
      local_activity_options: T.unsafe(nil)
    ); end
  end
end

# ============================================================
# Temporalio::Worker::Tuner::SlotSupplier
# ============================================================

class Temporalio::Worker::Tuner::SlotSupplier; end

# Fixed-size slot supplier.
class Temporalio::Worker::Tuner::SlotSupplier::Fixed < ::Temporalio::Worker::Tuner::SlotSupplier
  extend T::Sig

  sig { returns(Integer) }
  def slots; end

  sig { params(slots: Integer).void }
  def initialize(slots); end
end

# Resource-based slot supplier.
class Temporalio::Worker::Tuner::SlotSupplier::ResourceBased < ::Temporalio::Worker::Tuner::SlotSupplier
  extend T::Sig

  sig { returns(Temporalio::Worker::Tuner::ResourceBasedTunerOptions) }
  def tuner_options; end

  sig { returns(Temporalio::Worker::Tuner::ResourceBasedSlotOptions) }
  def slot_options; end

  sig do
    params(
      tuner_options: Temporalio::Worker::Tuner::ResourceBasedTunerOptions,
      slot_options: Temporalio::Worker::Tuner::ResourceBasedSlotOptions
    ).void
  end
  def initialize(tuner_options:, slot_options:); end
end

# Custom slot supplier with callbacks.
class Temporalio::Worker::Tuner::SlotSupplier::Custom < ::Temporalio::Worker::Tuner::SlotSupplier
  extend T::Sig

  sig do
    params(
      context: ReserveContext,
      cancellation: Temporalio::Cancellation,
      block: T.proc.params(arg0: T.untyped).void
    ).void
  end
  def reserve_slot(context, cancellation, &block); end

  sig { params(context: ReserveContext).returns(T.untyped) }
  def try_reserve_slot(context); end

  sig { params(context: MarkUsedContext).void }
  def mark_slot_used(context); end

  sig { params(context: ReleaseContext).void }
  def release_slot(context); end
end

# Context provided for slot reservation on custom slot supplier.
class Temporalio::Worker::Tuner::SlotSupplier::Custom::ReserveContext < ::Data
  extend T::Sig

  sig { returns(Symbol) }
  def slot_type; end

  sig { returns(String) }
  def task_queue; end

  sig { returns(String) }
  def worker_identity; end

  sig { returns(String) }
  def worker_deployment_name; end

  sig { returns(String) }
  def worker_build_id; end

  sig { returns(T::Boolean) }
  def sticky?; end
end

# Context provided for marking a slot used.
class Temporalio::Worker::Tuner::SlotSupplier::Custom::MarkUsedContext < ::Data
  extend T::Sig

  sig { returns(T.any(Temporalio::Worker::Tuner::SlotSupplier::Custom::SlotInfo::Workflow, Temporalio::Worker::Tuner::SlotSupplier::Custom::SlotInfo::Activity, Temporalio::Worker::Tuner::SlotSupplier::Custom::SlotInfo::LocalActivity, Temporalio::Worker::Tuner::SlotSupplier::Custom::SlotInfo::Nexus)) }
  def slot_info; end

  sig { returns(T.untyped) }
  def permit; end
end

# Context provided for releasing a slot.
class Temporalio::Worker::Tuner::SlotSupplier::Custom::ReleaseContext < ::Data
  extend T::Sig

  sig { returns(T.nilable(T.any(Temporalio::Worker::Tuner::SlotSupplier::Custom::SlotInfo::Workflow, Temporalio::Worker::Tuner::SlotSupplier::Custom::SlotInfo::Activity, Temporalio::Worker::Tuner::SlotSupplier::Custom::SlotInfo::LocalActivity, Temporalio::Worker::Tuner::SlotSupplier::Custom::SlotInfo::Nexus))) }
  def slot_info; end

  sig { returns(T.untyped) }
  def permit; end
end

module Temporalio::Worker::Tuner::SlotSupplier::Custom::SlotInfo; end

class Temporalio::Worker::Tuner::SlotSupplier::Custom::SlotInfo::Workflow < ::Data
  extend T::Sig

  sig { returns(String) }
  def workflow_type; end

  sig { returns(T::Boolean) }
  def sticky?; end
end

class Temporalio::Worker::Tuner::SlotSupplier::Custom::SlotInfo::Activity < ::Data
  extend T::Sig

  sig { returns(String) }
  def activity_type; end
end

class Temporalio::Worker::Tuner::SlotSupplier::Custom::SlotInfo::LocalActivity < ::Data
  extend T::Sig

  sig { returns(String) }
  def activity_type; end
end

class Temporalio::Worker::Tuner::SlotSupplier::Custom::SlotInfo::Nexus < ::Data
  extend T::Sig

  sig { returns(String) }
  def service; end

  sig { returns(String) }
  def operation; end
end

# Options for resource-based tuner.
class Temporalio::Worker::Tuner::ResourceBasedTunerOptions < ::Data
  extend T::Sig

  sig { returns(Float) }
  def target_memory_usage; end

  sig { returns(Float) }
  def target_cpu_usage; end

  sig { params(target_memory_usage: Float, target_cpu_usage: Float).void }
  def initialize(target_memory_usage:, target_cpu_usage:); end
end

# Options for a specific slot type being used with ResourceBased.
class Temporalio::Worker::Tuner::ResourceBasedSlotOptions < ::Data
  extend T::Sig

  sig { returns(T.nilable(Integer)) }
  def min_slots; end

  sig { returns(T.nilable(Integer)) }
  def max_slots; end

  sig { returns(T.nilable(Float)) }
  def ramp_throttle; end

  sig { params(min_slots: T.nilable(Integer), max_slots: T.nilable(Integer), ramp_throttle: T.nilable(Float)).void }
  def initialize(min_slots:, max_slots:, ramp_throttle:); end
end

# ============================================================
# Temporalio::Worker::ThreadPool
# ============================================================

class Temporalio::Worker::ThreadPool
  extend T::Sig

  sig { returns(Temporalio::Worker::ThreadPool) }
  def self.default; end

  sig { params(max_threads: T.nilable(Integer), idle_timeout: Float).void }
  def initialize(max_threads: T.unsafe(nil), idle_timeout: T.unsafe(nil)); end

  sig { params(block: T.proc.void).void }
  def execute(&block); end

  sig { returns(Integer) }
  def largest_length; end

  sig { returns(Integer) }
  def scheduled_task_count; end

  sig { returns(Integer) }
  def completed_task_count; end

  sig { returns(Integer) }
  def active_count; end

  sig { returns(Integer) }
  def length; end

  sig { returns(Integer) }
  def queue_length; end

  sig { void }
  def shutdown; end

  sig { void }
  def kill; end
end

# ============================================================
# Temporalio::Worker::PollerBehavior
# ============================================================

class Temporalio::Worker::PollerBehavior; end

class Temporalio::Worker::PollerBehavior::SimpleMaximum < ::Temporalio::Worker::PollerBehavior
  extend T::Sig

  sig { returns(Integer) }
  def maximum; end

  sig { params(maximum: Integer).void }
  def initialize(maximum); end
end

class Temporalio::Worker::PollerBehavior::Autoscaling < ::Temporalio::Worker::PollerBehavior
  extend T::Sig

  sig { returns(Integer) }
  def minimum; end

  sig { returns(Integer) }
  def maximum; end

  sig { returns(Integer) }
  def initial; end

  sig { params(minimum: Integer, maximum: Integer, initial: Integer).void }
  def initialize(minimum: T.unsafe(nil), maximum: T.unsafe(nil), initial: T.unsafe(nil)); end
end

# ============================================================
# Temporalio::Worker::DeploymentOptions
# ============================================================

class Temporalio::Worker::DeploymentOptions < ::Data
  extend T::Sig

  sig { returns(Temporalio::WorkerDeploymentVersion) }
  def version; end

  sig { returns(T::Boolean) }
  def use_worker_versioning; end

  sig { returns(Integer) }
  def default_versioning_behavior; end

  sig do
    params(
      version: Temporalio::WorkerDeploymentVersion,
      use_worker_versioning: T::Boolean,
      default_versioning_behavior: Integer
    ).void
  end
  def initialize(version:, use_worker_versioning: T.unsafe(nil), default_versioning_behavior: T.unsafe(nil)); end
end

# ============================================================
# Temporalio::Worker::Interceptor
# ============================================================

module Temporalio::Worker::Interceptor; end

module Temporalio::Worker::Interceptor::Activity
  extend T::Sig

  sig { params(next_interceptor: Temporalio::Worker::Interceptor::Activity::Inbound).returns(Temporalio::Worker::Interceptor::Activity::Inbound) }
  def intercept_activity(next_interceptor); end
end

class Temporalio::Worker::Interceptor::Activity::ExecuteInput < ::Data
  extend T::Sig

  sig { returns(Proc) }
  def proc; end

  sig { returns(T::Array[T.nilable(Object)]) }
  def args; end

  sig { returns(T.nilable(Object)) }
  def result_hint; end

  sig { returns(T::Hash[String, T.nilable(Object)]) }
  def headers; end
end

class Temporalio::Worker::Interceptor::Activity::HeartbeatInput < ::Data
  extend T::Sig

  sig { returns(T::Array[T.nilable(Object)]) }
  def details; end

  sig { returns(T.nilable(T::Array[Object])) }
  def detail_hints; end
end

class Temporalio::Worker::Interceptor::Activity::Inbound
  extend T::Sig

  sig { returns(Temporalio::Worker::Interceptor::Activity::Inbound) }
  def next_interceptor; end

  sig { params(next_interceptor: Temporalio::Worker::Interceptor::Activity::Inbound).void }
  def initialize(next_interceptor); end

  sig { params(outbound: Temporalio::Worker::Interceptor::Activity::Outbound).returns(Temporalio::Worker::Interceptor::Activity::Outbound) }
  def init(outbound); end

  sig { params(input: Temporalio::Worker::Interceptor::Activity::ExecuteInput).returns(T.nilable(Object)) }
  def execute(input); end
end

class Temporalio::Worker::Interceptor::Activity::Outbound
  extend T::Sig

  sig { returns(Temporalio::Worker::Interceptor::Activity::Outbound) }
  def next_interceptor; end

  sig { params(next_interceptor: Temporalio::Worker::Interceptor::Activity::Outbound).void }
  def initialize(next_interceptor); end

  sig { params(input: Temporalio::Worker::Interceptor::Activity::HeartbeatInput).void }
  def heartbeat(input); end
end

module Temporalio::Worker::Interceptor::Workflow
  extend T::Sig

  sig { params(next_interceptor: Temporalio::Worker::Interceptor::Workflow::Inbound).returns(Temporalio::Worker::Interceptor::Workflow::Inbound) }
  def intercept_workflow(next_interceptor); end
end

class Temporalio::Worker::Interceptor::Workflow::ExecuteInput < ::Data
  extend T::Sig

  sig { returns(T::Array[T.nilable(Object)]) }
  def args; end

  sig { returns(T::Hash[String, T.nilable(Object)]) }
  def headers; end
end

class Temporalio::Worker::Interceptor::Workflow::HandleSignalInput < ::Data
  extend T::Sig

  sig { returns(String) }
  def signal; end

  sig { returns(T::Array[T.nilable(Object)]) }
  def args; end

  sig { returns(Temporalio::Workflow::Definition::Signal) }
  def definition; end

  sig { returns(T::Hash[String, T.nilable(Object)]) }
  def headers; end
end

class Temporalio::Worker::Interceptor::Workflow::HandleQueryInput < ::Data
  extend T::Sig

  sig { returns(String) }
  def id; end

  sig { returns(String) }
  def query; end

  sig { returns(T::Array[T.nilable(Object)]) }
  def args; end

  sig { returns(Temporalio::Workflow::Definition::Query) }
  def definition; end

  sig { returns(T::Hash[String, T.nilable(Object)]) }
  def headers; end
end

class Temporalio::Worker::Interceptor::Workflow::HandleUpdateInput < ::Data
  extend T::Sig

  sig { returns(String) }
  def id; end

  sig { returns(String) }
  def update; end

  sig { returns(T::Array[T.nilable(Object)]) }
  def args; end

  sig { returns(Temporalio::Workflow::Definition::Update) }
  def definition; end

  sig { returns(T::Hash[String, T.nilable(Object)]) }
  def headers; end
end

class Temporalio::Worker::Interceptor::Workflow::Inbound
  extend T::Sig

  sig { returns(Temporalio::Worker::Interceptor::Workflow::Inbound) }
  def next_interceptor; end

  sig { params(next_interceptor: Temporalio::Worker::Interceptor::Workflow::Inbound).void }
  def initialize(next_interceptor); end

  sig { params(outbound: Temporalio::Worker::Interceptor::Workflow::Outbound).returns(Temporalio::Worker::Interceptor::Workflow::Outbound) }
  def init(outbound); end

  sig { params(input: Temporalio::Worker::Interceptor::Workflow::ExecuteInput).returns(T.nilable(Object)) }
  def execute(input); end

  sig { params(input: Temporalio::Worker::Interceptor::Workflow::HandleSignalInput).void }
  def handle_signal(input); end

  sig { params(input: Temporalio::Worker::Interceptor::Workflow::HandleQueryInput).returns(T.nilable(Object)) }
  def handle_query(input); end

  sig { params(input: Temporalio::Worker::Interceptor::Workflow::HandleUpdateInput).void }
  def validate_update(input); end

  sig { params(input: Temporalio::Worker::Interceptor::Workflow::HandleUpdateInput).returns(T.nilable(Object)) }
  def handle_update(input); end
end

class Temporalio::Worker::Interceptor::Workflow::CancelExternalWorkflowInput < ::Data
  extend T::Sig

  sig { returns(String) }
  def id; end

  sig { returns(T.nilable(String)) }
  def run_id; end
end

class Temporalio::Worker::Interceptor::Workflow::ExecuteActivityInput < ::Data
  extend T::Sig

  sig { returns(String) }
  def activity; end

  sig { returns(T::Array[T.nilable(Object)]) }
  def args; end

  sig { returns(String) }
  def task_queue; end

  sig { returns(T.nilable(String)) }
  def summary; end

  sig { returns(T.nilable(T.any(Integer, Float))) }
  def schedule_to_close_timeout; end

  sig { returns(T.nilable(T.any(Integer, Float))) }
  def schedule_to_start_timeout; end

  sig { returns(T.nilable(T.any(Integer, Float))) }
  def start_to_close_timeout; end

  sig { returns(T.nilable(T.any(Integer, Float))) }
  def heartbeat_timeout; end

  sig { returns(T.nilable(Temporalio::RetryPolicy)) }
  def retry_policy; end

  sig { returns(Temporalio::Cancellation) }
  def cancellation; end

  sig { returns(Integer) }
  def cancellation_type; end

  sig { returns(T.nilable(String)) }
  def activity_id; end

  sig { returns(T::Boolean) }
  def disable_eager_execution; end

  sig { returns(Temporalio::Priority) }
  def priority; end

  sig { returns(T.nilable(T::Array[Object])) }
  def arg_hints; end

  sig { returns(T.nilable(Object)) }
  def result_hint; end

  sig { returns(T::Hash[String, T.nilable(Object)]) }
  def headers; end
end

class Temporalio::Worker::Interceptor::Workflow::ExecuteLocalActivityInput < ::Data
  extend T::Sig

  sig { returns(String) }
  def activity; end

  sig { returns(T::Array[T.nilable(Object)]) }
  def args; end

  sig { returns(T.nilable(String)) }
  def summary; end

  sig { returns(T.nilable(T.any(Integer, Float))) }
  def schedule_to_close_timeout; end

  sig { returns(T.nilable(T.any(Integer, Float))) }
  def schedule_to_start_timeout; end

  sig { returns(T.nilable(T.any(Integer, Float))) }
  def start_to_close_timeout; end

  sig { returns(T.nilable(Temporalio::RetryPolicy)) }
  def retry_policy; end

  sig { returns(T.nilable(T.any(Integer, Float))) }
  def local_retry_threshold; end

  sig { returns(Temporalio::Cancellation) }
  def cancellation; end

  sig { returns(Integer) }
  def cancellation_type; end

  sig { returns(T.nilable(String)) }
  def activity_id; end

  sig { returns(T.nilable(T::Array[Object])) }
  def arg_hints; end

  sig { returns(T.nilable(Object)) }
  def result_hint; end

  sig { returns(T::Hash[String, T.nilable(Object)]) }
  def headers; end
end

class Temporalio::Worker::Interceptor::Workflow::InitializeContinueAsNewErrorInput < ::Data
  extend T::Sig

  sig { returns(Temporalio::Workflow::ContinueAsNewError) }
  def error; end
end

class Temporalio::Worker::Interceptor::Workflow::SignalChildWorkflowInput < ::Data
  extend T::Sig

  sig { returns(String) }
  def id; end

  sig { returns(String) }
  def signal; end

  sig { returns(T::Array[T.nilable(Object)]) }
  def args; end

  sig { returns(Temporalio::Cancellation) }
  def cancellation; end

  sig { returns(T.nilable(T::Array[Object])) }
  def arg_hints; end

  sig { returns(T::Hash[String, T.nilable(Object)]) }
  def headers; end
end

class Temporalio::Worker::Interceptor::Workflow::SignalExternalWorkflowInput < ::Data
  extend T::Sig

  sig { returns(String) }
  def id; end

  sig { returns(T.nilable(String)) }
  def run_id; end

  sig { returns(String) }
  def signal; end

  sig { returns(T::Array[T.nilable(Object)]) }
  def args; end

  sig { returns(Temporalio::Cancellation) }
  def cancellation; end

  sig { returns(T.nilable(T::Array[Object])) }
  def arg_hints; end

  sig { returns(T::Hash[String, T.nilable(Object)]) }
  def headers; end
end

class Temporalio::Worker::Interceptor::Workflow::SleepInput < ::Data
  extend T::Sig

  sig { returns(T.nilable(T.any(Integer, Float))) }
  def duration; end

  sig { returns(T.nilable(String)) }
  def summary; end

  sig { returns(Temporalio::Cancellation) }
  def cancellation; end
end

class Temporalio::Worker::Interceptor::Workflow::StartChildWorkflowInput < ::Data
  extend T::Sig

  sig { returns(String) }
  def workflow; end

  sig { returns(T::Array[T.nilable(Object)]) }
  def args; end

  sig { returns(String) }
  def id; end

  sig { returns(String) }
  def task_queue; end

  sig { returns(T.nilable(String)) }
  def static_summary; end

  sig { returns(T.nilable(String)) }
  def static_details; end

  sig { returns(Temporalio::Cancellation) }
  def cancellation; end

  sig { returns(Integer) }
  def cancellation_type; end

  sig { returns(Integer) }
  def parent_close_policy; end

  sig { returns(T.nilable(T.any(Integer, Float))) }
  def execution_timeout; end

  sig { returns(T.nilable(T.any(Integer, Float))) }
  def run_timeout; end

  sig { returns(T.nilable(T.any(Integer, Float))) }
  def task_timeout; end

  sig { returns(Integer) }
  def id_reuse_policy; end

  sig { returns(T.nilable(Temporalio::RetryPolicy)) }
  def retry_policy; end

  sig { returns(T.nilable(String)) }
  def cron_schedule; end

  sig { returns(T.nilable(T::Hash[T.any(String, Symbol), T.nilable(Object)])) }
  def memo; end

  sig { returns(T.nilable(Temporalio::SearchAttributes)) }
  def search_attributes; end

  sig { returns(Temporalio::Priority) }
  def priority; end

  sig { returns(T.nilable(T::Array[Object])) }
  def arg_hints; end

  sig { returns(T.nilable(Object)) }
  def result_hint; end

  sig { returns(T::Hash[String, T.nilable(Object)]) }
  def headers; end
end

class Temporalio::Worker::Interceptor::Workflow::StartNexusOperationInput < ::Data
  extend T::Sig

  sig { returns(String) }
  def endpoint; end

  sig { returns(String) }
  def service; end

  sig { returns(String) }
  def operation; end

  sig { returns(T.nilable(Object)) }
  def arg; end

  sig { returns(T.nilable(T.any(Integer, Float))) }
  def schedule_to_close_timeout; end

  sig { returns(T.nilable(T.any(Integer, Float))) }
  def schedule_to_start_timeout; end

  sig { returns(T.nilable(T.any(Integer, Float))) }
  def start_to_close_timeout; end

  sig { returns(Integer) }
  def cancellation_type; end

  sig { returns(T.nilable(String)) }
  def summary; end

  sig { returns(Temporalio::Cancellation) }
  def cancellation; end

  sig { returns(T.nilable(Object)) }
  def arg_hint; end

  sig { returns(T.nilable(Object)) }
  def result_hint; end

  sig { returns(T::Hash[String, String]) }
  def headers; end
end

class Temporalio::Worker::Interceptor::Workflow::Outbound
  extend T::Sig

  sig { returns(Temporalio::Worker::Interceptor::Workflow::Outbound) }
  def next_interceptor; end

  sig { params(next_interceptor: Temporalio::Worker::Interceptor::Workflow::Outbound).void }
  def initialize(next_interceptor); end

  sig { params(input: Temporalio::Worker::Interceptor::Workflow::CancelExternalWorkflowInput).void }
  def cancel_external_workflow(input); end

  sig { params(input: Temporalio::Worker::Interceptor::Workflow::ExecuteActivityInput).returns(T.nilable(Object)) }
  def execute_activity(input); end

  sig { params(input: Temporalio::Worker::Interceptor::Workflow::ExecuteLocalActivityInput).returns(T.nilable(Object)) }
  def execute_local_activity(input); end

  sig { params(input: Temporalio::Worker::Interceptor::Workflow::InitializeContinueAsNewErrorInput).void }
  def initialize_continue_as_new_error(input); end

  sig { params(input: Temporalio::Worker::Interceptor::Workflow::SignalChildWorkflowInput).void }
  def signal_child_workflow(input); end

  sig { params(input: Temporalio::Worker::Interceptor::Workflow::SignalExternalWorkflowInput).void }
  def signal_external_workflow(input); end

  sig { params(input: Temporalio::Worker::Interceptor::Workflow::SleepInput).void }
  def sleep(input); end

  sig { params(input: Temporalio::Worker::Interceptor::Workflow::StartChildWorkflowInput).returns(Temporalio::Workflow::ChildWorkflowHandle) }
  def start_child_workflow(input); end

  sig { params(input: Temporalio::Worker::Interceptor::Workflow::StartNexusOperationInput).returns(Temporalio::Workflow::NexusOperationHandle) }
  def start_nexus_operation(input); end
end

# ============================================================
# Temporalio::Worker::Plugin
# ============================================================

module Temporalio::Worker::Plugin
  extend T::Sig

  sig { returns(String) }
  def name; end

  sig { params(options: Temporalio::Worker::Options).returns(Temporalio::Worker::Options) }
  def configure_worker(options); end

  sig { params(options: Temporalio::Worker::Plugin::RunWorkerOptions, next_call: T.proc.params(arg0: Temporalio::Worker::Plugin::RunWorkerOptions).returns(T.untyped)).returns(T.untyped) }
  def run_worker(options, next_call); end

  sig { params(options: Temporalio::Worker::WorkflowReplayer::Options).returns(Temporalio::Worker::WorkflowReplayer::Options) }
  def configure_workflow_replayer(options); end

  sig { params(options: Temporalio::Worker::Plugin::WithWorkflowReplayWorkerOptions, next_call: T.proc.params(arg0: Temporalio::Worker::Plugin::WithWorkflowReplayWorkerOptions).returns(T.untyped)).returns(T.untyped) }
  def with_workflow_replay_worker(options, next_call); end
end

class Temporalio::Worker::Plugin::RunWorkerOptions < ::Data
  extend T::Sig

  sig { returns(Temporalio::Worker) }
  def worker; end

  sig { returns(Temporalio::Cancellation) }
  def cancellation; end

  sig { returns(T::Array[T.any(String, Integer)]) }
  def shutdown_signals; end

  sig { returns(T.nilable(Exception)) }
  def raise_in_block_on_shutdown; end

  sig { params(kwargs: T.untyped).returns(Temporalio::Worker::Plugin::RunWorkerOptions) }
  def with(**kwargs); end
end

class Temporalio::Worker::Plugin::WithWorkflowReplayWorkerOptions < ::Data
  extend T::Sig

  sig { returns(Temporalio::Worker::WorkflowReplayer::ReplayWorker) }
  def worker; end

  sig { params(kwargs: T.untyped).returns(Temporalio::Worker::Plugin::WithWorkflowReplayWorkerOptions) }
  def with(**kwargs); end
end

# ============================================================
# Temporalio::Worker::WorkflowReplayer
# ============================================================

class Temporalio::Worker::WorkflowReplayer
  extend T::Sig

  sig { returns(Temporalio::Worker::WorkflowReplayer::Options) }
  def options; end

  sig do
    params(
      workflows: T::Array[T.any(T.class_of(Temporalio::Workflow::Definition), Temporalio::Workflow::Definition::Info)],
      namespace: String,
      task_queue: String,
      data_converter: Temporalio::Converters::DataConverter,
      workflow_executor: Temporalio::Worker::WorkflowExecutor,
      plugins: T::Array[Temporalio::Worker::Plugin],
      interceptors: T::Array[Temporalio::Worker::Interceptor::Workflow],
      identity: T.nilable(String),
      logger: Logger,
      illegal_workflow_calls: T::Hash[String, T.any(Symbol, T::Array[Symbol])],
      workflow_failure_exception_types: T::Array[T.class_of(Exception)],
      workflow_payload_codec_thread_pool: T.nilable(Temporalio::Worker::ThreadPool),
      unsafe_workflow_io_enabled: T::Boolean,
      debug_mode: T::Boolean,
      runtime: Temporalio::Runtime,
      block: T.nilable(T.proc.params(worker: Temporalio::Worker::WorkflowReplayer::ReplayWorker).returns(T.untyped))
    ).void
  end
  def initialize(
    workflows:,
    namespace: T.unsafe(nil),
    task_queue: T.unsafe(nil),
    data_converter: T.unsafe(nil),
    workflow_executor: T.unsafe(nil),
    plugins: T.unsafe(nil),
    interceptors: T.unsafe(nil),
    identity: T.unsafe(nil),
    logger: T.unsafe(nil),
    illegal_workflow_calls: T.unsafe(nil),
    workflow_failure_exception_types: T.unsafe(nil),
    workflow_payload_codec_thread_pool: T.unsafe(nil),
    unsafe_workflow_io_enabled: T.unsafe(nil),
    debug_mode: T.unsafe(nil),
    runtime: T.unsafe(nil),
    &block
  ); end

  sig do
    params(
      history: Temporalio::WorkflowHistory,
      raise_on_replay_failure: T::Boolean
    ).returns(Temporalio::Worker::WorkflowReplayer::ReplayResult)
  end
  def replay_workflow(history, raise_on_replay_failure: T.unsafe(nil)); end

  sig do
    params(
      histories: T::Enumerable[Temporalio::WorkflowHistory],
      raise_on_replay_failure: T::Boolean
    ).returns(T::Array[Temporalio::Worker::WorkflowReplayer::ReplayResult])
  end
  def replay_workflows(histories, raise_on_replay_failure: T.unsafe(nil)); end

  sig do
    type_parameters(:T)
      .params(block: T.proc.params(worker: Temporalio::Worker::WorkflowReplayer::ReplayWorker).returns(T.type_parameter(:T)))
      .returns(T.type_parameter(:T))
  end
  def with_replay_worker(&block); end
end

class Temporalio::Worker::WorkflowReplayer::Options < ::Data
  extend T::Sig

  sig { returns(T::Array[T.any(T.class_of(Temporalio::Workflow::Definition), Temporalio::Workflow::Definition::Info)]) }
  def workflows; end

  sig { returns(String) }
  def namespace; end

  sig { returns(String) }
  def task_queue; end

  sig { returns(Temporalio::Converters::DataConverter) }
  def data_converter; end

  sig { returns(Temporalio::Worker::WorkflowExecutor) }
  def workflow_executor; end

  sig { returns(T::Array[Temporalio::Worker::Plugin]) }
  def plugins; end

  sig { returns(T::Array[Temporalio::Worker::Interceptor::Workflow]) }
  def interceptors; end

  sig { returns(T.nilable(String)) }
  def identity; end

  sig { returns(Logger) }
  def logger; end

  sig { returns(T::Hash[String, T.any(Symbol, T::Array[Symbol])]) }
  def illegal_workflow_calls; end

  sig { returns(T::Array[T.class_of(Exception)]) }
  def workflow_failure_exception_types; end

  sig { returns(T.nilable(Temporalio::Worker::ThreadPool)) }
  def workflow_payload_codec_thread_pool; end

  sig { returns(T::Boolean) }
  def unsafe_workflow_io_enabled; end

  sig { returns(T::Boolean) }
  def debug_mode; end

  sig { returns(Temporalio::Runtime) }
  def runtime; end

  sig { params(kwargs: T.untyped).returns(Temporalio::Worker::WorkflowReplayer::Options) }
  def with(**kwargs); end
end

class Temporalio::Worker::WorkflowReplayer::ReplayResult
  extend T::Sig

  sig { returns(Temporalio::WorkflowHistory) }
  def history; end

  sig { returns(T.nilable(Exception)) }
  def replay_failure; end

  sig { params(history: Temporalio::WorkflowHistory, replay_failure: T.nilable(Exception)).void }
  def initialize(history:, replay_failure:); end
end

class Temporalio::Worker::WorkflowReplayer::ReplayWorker
  extend T::Sig

  sig do
    params(
      history: Temporalio::WorkflowHistory,
      raise_on_replay_failure: T::Boolean
    ).returns(Temporalio::Worker::WorkflowReplayer::ReplayResult)
  end
  def replay_workflow(history, raise_on_replay_failure: T.unsafe(nil)); end
end

# ============================================================
# Temporalio::Worker::IllegalWorkflowCallValidator
# ============================================================

class Temporalio::Worker::IllegalWorkflowCallValidator
  extend T::Sig

  sig { returns(T.nilable(Symbol)) }
  def method_name; end

  sig { returns(T.proc.params(arg0: Temporalio::Worker::IllegalWorkflowCallValidator::CallInfo).void) }
  def block; end

  sig { params(method_name: T.nilable(Symbol), block: T.proc.params(arg0: Temporalio::Worker::IllegalWorkflowCallValidator::CallInfo).void).void }
  def initialize(method_name: T.unsafe(nil), &block); end

  sig { returns(T::Array[Temporalio::Worker::IllegalWorkflowCallValidator]) }
  def self.default_time_validators; end

  sig { returns(Temporalio::Worker::IllegalWorkflowCallValidator) }
  def self.known_safe_mutex_validator; end
end

class Temporalio::Worker::IllegalWorkflowCallValidator::CallInfo < ::Data
  extend T::Sig

  sig { returns(String) }
  def class_name; end

  sig { returns(Symbol) }
  def method_name; end

  sig { returns(TracePoint) }
  def trace_point; end
end

# ============================================================
# Temporalio::Workflow (module-level methods)
# ============================================================

module Temporalio::Workflow
  class << self
    extend T::Sig

    sig { returns(T::Boolean) }
    def all_handlers_finished?; end

    sig { returns(Temporalio::Cancellation) }
    def cancellation; end

    sig { returns(T::Boolean) }
    def continue_as_new_suggested; end

    sig { params(endpoint: T.any(Symbol, String), service: T.any(Symbol, String)).returns(Temporalio::Workflow::NexusClient) }
    def create_nexus_client(endpoint:, service:); end

    sig { returns(T::Array[Integer]) }
    def suggest_continue_as_new_reasons; end

    sig { returns(T::Boolean) }
    def target_worker_deployment_version_changed?; end

    sig { returns(String) }
    def current_details; end

    sig { params(details: T.nilable(String)).void }
    def current_details=(details); end

    sig { returns(Integer) }
    def current_history_length; end

    sig { returns(T.nilable(Temporalio::WorkerDeploymentVersion)) }
    def current_deployment_version; end

    sig { returns(Integer) }
    def current_history_size; end

    sig { returns(T.nilable(Temporalio::Workflow::UpdateInfo)) }
    def current_update_info; end

    sig { params(patch_id: T.any(Symbol, String)).void }
    def deprecate_patch(patch_id); end

    sig do
      params(
        activity: T.any(T.class_of(Temporalio::Activity::Definition), Symbol, String),
        args: T.nilable(Object),
        task_queue: String,
        summary: T.nilable(String),
        schedule_to_close_timeout: T.nilable(T.any(Integer, Float)),
        schedule_to_start_timeout: T.nilable(T.any(Integer, Float)),
        start_to_close_timeout: T.nilable(T.any(Integer, Float)),
        heartbeat_timeout: T.nilable(T.any(Integer, Float)),
        retry_policy: T.nilable(Temporalio::RetryPolicy),
        cancellation: Temporalio::Cancellation,
        cancellation_type: Integer,
        activity_id: T.nilable(String),
        disable_eager_execution: T::Boolean,
        priority: Temporalio::Priority,
        arg_hints: T.nilable(T::Array[Object]),
        result_hint: T.nilable(Object)
      ).returns(T.nilable(Object))
    end
    def execute_activity(
      activity,
      *args,
      task_queue: T.unsafe(nil),
      summary: T.unsafe(nil),
      schedule_to_close_timeout: T.unsafe(nil),
      schedule_to_start_timeout: T.unsafe(nil),
      start_to_close_timeout: T.unsafe(nil),
      heartbeat_timeout: T.unsafe(nil),
      retry_policy: T.unsafe(nil),
      cancellation: T.unsafe(nil),
      cancellation_type: T.unsafe(nil),
      activity_id: T.unsafe(nil),
      disable_eager_execution: T.unsafe(nil),
      priority: T.unsafe(nil),
      arg_hints: T.unsafe(nil),
      result_hint: T.unsafe(nil)
    ); end

    sig do
      params(
        workflow: T.any(T.class_of(Temporalio::Workflow::Definition), Temporalio::Workflow::Definition::Info, Symbol, String),
        args: T.nilable(Object),
        id: String,
        task_queue: String,
        static_summary: T.nilable(String),
        static_details: T.nilable(String),
        cancellation: Temporalio::Cancellation,
        cancellation_type: Integer,
        parent_close_policy: Integer,
        execution_timeout: T.nilable(T.any(Integer, Float)),
        run_timeout: T.nilable(T.any(Integer, Float)),
        task_timeout: T.nilable(T.any(Integer, Float)),
        id_reuse_policy: Integer,
        retry_policy: T.nilable(Temporalio::RetryPolicy),
        cron_schedule: T.nilable(String),
        memo: T.nilable(T::Hash[T.any(String, Symbol), T.nilable(Object)]),
        search_attributes: T.nilable(Temporalio::SearchAttributes),
        priority: Temporalio::Priority,
        arg_hints: T.nilable(T::Array[Object]),
        result_hint: T.nilable(Object)
      ).returns(T.nilable(Object))
    end
    def execute_child_workflow(
      workflow,
      *args,
      id: T.unsafe(nil),
      task_queue: T.unsafe(nil),
      static_summary: T.unsafe(nil),
      static_details: T.unsafe(nil),
      cancellation: T.unsafe(nil),
      cancellation_type: T.unsafe(nil),
      parent_close_policy: T.unsafe(nil),
      execution_timeout: T.unsafe(nil),
      run_timeout: T.unsafe(nil),
      task_timeout: T.unsafe(nil),
      id_reuse_policy: T.unsafe(nil),
      retry_policy: T.unsafe(nil),
      cron_schedule: T.unsafe(nil),
      memo: T.unsafe(nil),
      search_attributes: T.unsafe(nil),
      priority: T.unsafe(nil),
      arg_hints: T.unsafe(nil),
      result_hint: T.unsafe(nil)
    ); end

    sig do
      params(
        activity: T.any(T.class_of(Temporalio::Activity::Definition), Symbol, String),
        args: T.nilable(Object),
        summary: T.nilable(String),
        schedule_to_close_timeout: T.nilable(T.any(Integer, Float)),
        schedule_to_start_timeout: T.nilable(T.any(Integer, Float)),
        start_to_close_timeout: T.nilable(T.any(Integer, Float)),
        retry_policy: T.nilable(Temporalio::RetryPolicy),
        local_retry_threshold: T.nilable(T.any(Integer, Float)),
        cancellation: Temporalio::Cancellation,
        cancellation_type: Integer,
        activity_id: T.nilable(String),
        arg_hints: T.nilable(T::Array[Object]),
        result_hint: T.nilable(Object)
      ).returns(T.nilable(Object))
    end
    def execute_local_activity(
      activity,
      *args,
      summary: T.unsafe(nil),
      schedule_to_close_timeout: T.unsafe(nil),
      schedule_to_start_timeout: T.unsafe(nil),
      start_to_close_timeout: T.unsafe(nil),
      retry_policy: T.unsafe(nil),
      local_retry_threshold: T.unsafe(nil),
      cancellation: T.unsafe(nil),
      cancellation_type: T.unsafe(nil),
      activity_id: T.unsafe(nil),
      arg_hints: T.unsafe(nil),
      result_hint: T.unsafe(nil)
    ); end

    sig { params(workflow_id: String, run_id: T.nilable(String)).returns(Temporalio::Workflow::ExternalWorkflowHandle) }
    def external_workflow_handle(workflow_id, run_id: T.unsafe(nil)); end

    sig { returns(T::Boolean) }
    def in_workflow?; end

    sig { returns(Temporalio::Workflow::Info) }
    def info; end

    sig { returns(T.nilable(Temporalio::Workflow::Definition)) }
    def instance; end

    sig { returns(Temporalio::ScopedLogger) }
    def logger; end

    sig { returns(T::Hash[String, T.nilable(Object)]) }
    def memo; end

    sig { returns(Temporalio::Metric::Meter) }
    def metric_meter; end

    sig { returns(Time) }
    def now; end

    sig { params(patch_id: T.any(Symbol, String)).returns(T::Boolean) }
    def patched(patch_id); end

    sig { returns(Temporalio::Converters::PayloadConverter) }
    def payload_converter; end

    sig { returns(T::Hash[T.nilable(String), Temporalio::Workflow::Definition::Query]) }
    def query_handlers; end

    sig { returns(Random) }
    def random; end

    sig { returns(Temporalio::SearchAttributes) }
    def search_attributes; end

    sig { returns(T::Hash[T.nilable(String), Temporalio::Workflow::Definition::Signal]) }
    def signal_handlers; end

    sig { params(duration: T.nilable(T.any(Integer, Float)), summary: T.nilable(String), cancellation: Temporalio::Cancellation).void }
    def sleep(duration, summary: T.unsafe(nil), cancellation: T.unsafe(nil)); end

    sig do
      params(
        workflow: T.any(T.class_of(Temporalio::Workflow::Definition), Temporalio::Workflow::Definition::Info, Symbol, String),
        args: T.nilable(Object),
        id: String,
        task_queue: String,
        static_summary: T.nilable(String),
        static_details: T.nilable(String),
        cancellation: Temporalio::Cancellation,
        cancellation_type: Integer,
        parent_close_policy: Integer,
        execution_timeout: T.nilable(T.any(Integer, Float)),
        run_timeout: T.nilable(T.any(Integer, Float)),
        task_timeout: T.nilable(T.any(Integer, Float)),
        id_reuse_policy: Integer,
        retry_policy: T.nilable(Temporalio::RetryPolicy),
        cron_schedule: T.nilable(String),
        memo: T.nilable(T::Hash[T.any(String, Symbol), T.nilable(Object)]),
        search_attributes: T.nilable(Temporalio::SearchAttributes),
        priority: Temporalio::Priority,
        arg_hints: T.nilable(T::Array[Object]),
        result_hint: T.nilable(Object)
      ).returns(Temporalio::Workflow::ChildWorkflowHandle)
    end
    def start_child_workflow(
      workflow,
      *args,
      id: T.unsafe(nil),
      task_queue: T.unsafe(nil),
      static_summary: T.unsafe(nil),
      static_details: T.unsafe(nil),
      cancellation: T.unsafe(nil),
      cancellation_type: T.unsafe(nil),
      parent_close_policy: T.unsafe(nil),
      execution_timeout: T.unsafe(nil),
      run_timeout: T.unsafe(nil),
      task_timeout: T.unsafe(nil),
      id_reuse_policy: T.unsafe(nil),
      retry_policy: T.unsafe(nil),
      cron_schedule: T.unsafe(nil),
      memo: T.unsafe(nil),
      search_attributes: T.unsafe(nil),
      priority: T.unsafe(nil),
      arg_hints: T.unsafe(nil),
      result_hint: T.unsafe(nil)
    ); end

    sig { returns(T::Hash[Object, Object]) }
    def storage; end

    sig do
      type_parameters(:T)
        .params(
          duration: T.nilable(T.any(Integer, Float)),
          exception_class: T.class_of(Exception),
          message: String,
          summary: T.nilable(String),
          block: T.proc.returns(T.type_parameter(:T))
        ).returns(T.type_parameter(:T))
    end
    def timeout(duration, exception_class = T.unsafe(nil), message = T.unsafe(nil), summary: T.unsafe(nil), &block); end

    sig { returns(T::Hash[T.nilable(String), Temporalio::Workflow::Definition::Update]) }
    def update_handlers; end

    sig { params(hash: T::Hash[T.any(Symbol, String), T.nilable(Object)]).void }
    def upsert_memo(hash); end

    sig { params(updates: Temporalio::SearchAttributes::Update).void }
    def upsert_search_attributes(*updates); end

    sig do
      type_parameters(:T)
        .params(
          cancellation: T.nilable(Temporalio::Cancellation),
          block: T.proc.returns(T.type_parameter(:T))
        ).returns(T.type_parameter(:T))
    end
    def wait_condition(cancellation: T.unsafe(nil), &block); end
  end
end

# ============================================================
# Temporalio::Workflow::Unsafe
# ============================================================

module Temporalio::Workflow::Unsafe
  class << self
    extend T::Sig

    sig { returns(T::Boolean) }
    def replaying?; end

    sig { returns(T::Boolean) }
    def replaying_history_events?; end

    sig { type_parameters(:T).params(block: T.proc.returns(T.type_parameter(:T))).returns(T.type_parameter(:T)) }
    def illegal_call_tracing_disabled(&block); end

    sig { type_parameters(:T).params(block: T.proc.returns(T.type_parameter(:T))).returns(T.type_parameter(:T)) }
    def io_enabled(&block); end

    sig { type_parameters(:T).params(block: T.proc.returns(T.type_parameter(:T))).returns(T.type_parameter(:T)) }
    def durable_scheduler_disabled(&block); end
  end
end

# ============================================================
# Temporalio::Workflow::Definition
# ============================================================

class Temporalio::Workflow::Definition
  extend T::Sig

  sig { params(args: T.nilable(Object)).returns(T.nilable(Object)) }
  def execute(*args); end

  class << self
    extend T::Sig

    sig { params(workflow_name: T.any(String, Symbol)).void }
    def workflow_name(workflow_name); end

    sig { params(value: T::Boolean).void }
    def workflow_dynamic(value = T.unsafe(nil)); end

    sig { params(value: T::Boolean).void }
    def workflow_raw_args(value = T.unsafe(nil)); end

    sig { params(hints: Object).void }
    def workflow_arg_hint(*hints); end

    sig { params(hint: Object).void }
    def workflow_result_hint(hint); end

    sig { params(types: T.class_of(Exception)).void }
    def workflow_failure_exception_type(*types); end

    sig { params(attr_names: Symbol, description: T.nilable(String)).void }
    def workflow_query_attr_reader(*attr_names, description: T.unsafe(nil)); end

    sig { params(value: Integer).void }
    def workflow_versioning_behavior(value); end

    sig { params(value: T::Boolean).void }
    def workflow_init(value = T.unsafe(nil)); end

    sig do
      params(
        name: T.nilable(T.any(String, Symbol)),
        description: T.nilable(String),
        dynamic: T::Boolean,
        raw_args: T::Boolean,
        unfinished_policy: Integer,
        arg_hints: T.nilable(T.any(Object, T::Array[Object]))
      ).void
    end
    def workflow_signal(
      name: T.unsafe(nil),
      description: T.unsafe(nil),
      dynamic: T.unsafe(nil),
      raw_args: T.unsafe(nil),
      unfinished_policy: T.unsafe(nil),
      arg_hints: T.unsafe(nil)
    ); end

    sig do
      params(
        name: T.nilable(T.any(String, Symbol)),
        description: T.nilable(String),
        dynamic: T::Boolean,
        raw_args: T::Boolean,
        arg_hints: T.nilable(T.any(Object, T::Array[Object])),
        result_hint: T.nilable(Object)
      ).void
    end
    def workflow_query(
      name: T.unsafe(nil),
      description: T.unsafe(nil),
      dynamic: T.unsafe(nil),
      raw_args: T.unsafe(nil),
      arg_hints: T.unsafe(nil),
      result_hint: T.unsafe(nil)
    ); end

    sig do
      params(
        name: T.nilable(T.any(String, Symbol)),
        description: T.nilable(String),
        dynamic: T::Boolean,
        raw_args: T::Boolean,
        unfinished_policy: Integer,
        arg_hints: T.nilable(T.any(Object, T::Array[Object])),
        result_hint: T.nilable(Object)
      ).void
    end
    def workflow_update(
      name: T.unsafe(nil),
      description: T.unsafe(nil),
      dynamic: T.unsafe(nil),
      raw_args: T.unsafe(nil),
      unfinished_policy: T.unsafe(nil),
      arg_hints: T.unsafe(nil),
      result_hint: T.unsafe(nil)
    ); end

    sig { params(update_method: Symbol).void }
    def workflow_update_validator(update_method); end

    sig { void }
    def workflow_dynamic_options; end
  end
end

# ============================================================
# Temporalio::Workflow::Definition::Info
# ============================================================

class Temporalio::Workflow::Definition::Info
  extend T::Sig

  sig { returns(T.class_of(Temporalio::Workflow::Definition)) }
  def workflow_class; end

  sig { returns(T.nilable(String)) }
  def override_name; end

  sig { returns(T::Boolean) }
  def dynamic; end

  sig { returns(T::Boolean) }
  def init; end

  sig { returns(T::Boolean) }
  def raw_args; end

  sig { returns(T::Array[T.class_of(Exception)]) }
  def failure_exception_types; end

  sig { returns(T::Hash[T.nilable(String), Temporalio::Workflow::Definition::Signal]) }
  def signals; end

  sig { returns(T::Hash[T.nilable(String), Temporalio::Workflow::Definition::Query]) }
  def queries; end

  sig { returns(T::Hash[T.nilable(String), Temporalio::Workflow::Definition::Update]) }
  def updates; end

  sig { returns(T.nilable(Integer)) }
  def versioning_behavior; end

  sig { returns(T.nilable(Symbol)) }
  def dynamic_options_method; end

  sig { returns(T.nilable(T::Array[Object])) }
  def arg_hints; end

  sig { returns(T.nilable(Object)) }
  def result_hint; end

  sig { params(workflow_class: T.class_of(Temporalio::Workflow::Definition)).returns(Temporalio::Workflow::Definition::Info) }
  def self.from_class(workflow_class); end

  sig do
    params(
      workflow_class: T.class_of(Temporalio::Workflow::Definition),
      override_name: T.nilable(String),
      dynamic: T::Boolean,
      init: T::Boolean,
      raw_args: T::Boolean,
      failure_exception_types: T::Array[T.class_of(Exception)],
      signals: T::Hash[String, Temporalio::Workflow::Definition::Signal],
      queries: T::Hash[String, Temporalio::Workflow::Definition::Query],
      updates: T::Hash[String, Temporalio::Workflow::Definition::Update],
      versioning_behavior: T.nilable(Integer),
      dynamic_options_method: T.nilable(Symbol),
      arg_hints: T.nilable(T::Array[Object]),
      result_hint: T.nilable(Object)
    ).void
  end
  def initialize(
    workflow_class:,
    override_name: T.unsafe(nil),
    dynamic: T.unsafe(nil),
    init: T.unsafe(nil),
    raw_args: T.unsafe(nil),
    failure_exception_types: T.unsafe(nil),
    signals: T.unsafe(nil),
    queries: T.unsafe(nil),
    updates: T.unsafe(nil),
    versioning_behavior: T.unsafe(nil),
    dynamic_options_method: T.unsafe(nil),
    arg_hints: T.unsafe(nil),
    result_hint: T.unsafe(nil)
  ); end

  sig { returns(T.nilable(String)) }
  def name; end
end

# ============================================================
# Temporalio::Workflow::Definition::Signal
# ============================================================

class Temporalio::Workflow::Definition::Signal
  extend T::Sig

  sig { returns(T.nilable(String)) }
  def name; end

  sig { returns(T.any(Symbol, Proc)) }
  def to_invoke; end

  sig { returns(T.nilable(String)) }
  def description; end

  sig { returns(T::Boolean) }
  def raw_args; end

  sig { returns(Integer) }
  def unfinished_policy; end

  sig { returns(T.nilable(T::Array[Object])) }
  def arg_hints; end

  sig do
    params(
      name: T.nilable(String),
      to_invoke: T.any(Symbol, Proc),
      description: T.nilable(String),
      raw_args: T::Boolean,
      unfinished_policy: Integer,
      arg_hints: T.nilable(T::Array[Object])
    ).void
  end
  def initialize(name:, to_invoke:, description: T.unsafe(nil), raw_args: T.unsafe(nil), unfinished_policy: T.unsafe(nil), arg_hints: T.unsafe(nil)); end
end

# ============================================================
# Temporalio::Workflow::Definition::Query
# ============================================================

class Temporalio::Workflow::Definition::Query
  extend T::Sig

  sig { returns(T.nilable(String)) }
  def name; end

  sig { returns(T.any(Symbol, Proc)) }
  def to_invoke; end

  sig { returns(T.nilable(String)) }
  def description; end

  sig { returns(T::Boolean) }
  def raw_args; end

  sig { returns(T.nilable(T::Array[Object])) }
  def arg_hints; end

  sig { returns(T.nilable(Object)) }
  def result_hint; end

  sig do
    params(
      name: T.nilable(String),
      to_invoke: T.any(Symbol, Proc),
      description: T.nilable(String),
      raw_args: T::Boolean,
      arg_hints: T.nilable(T::Array[Object]),
      result_hint: T.nilable(Object)
    ).void
  end
  def initialize(name:, to_invoke:, description: T.unsafe(nil), raw_args: T.unsafe(nil), arg_hints: T.unsafe(nil), result_hint: T.unsafe(nil)); end
end

# ============================================================
# Temporalio::Workflow::Definition::Update
# ============================================================

class Temporalio::Workflow::Definition::Update
  extend T::Sig

  sig { returns(T.nilable(String)) }
  def name; end

  sig { returns(T.any(Symbol, Proc)) }
  def to_invoke; end

  sig { returns(T.nilable(String)) }
  def description; end

  sig { returns(T::Boolean) }
  def raw_args; end

  sig { returns(Integer) }
  def unfinished_policy; end

  sig { returns(T.nilable(T.any(Symbol, Proc))) }
  def validator_to_invoke; end

  sig { returns(T.nilable(T::Array[Object])) }
  def arg_hints; end

  sig { returns(T.nilable(Object)) }
  def result_hint; end

  sig do
    params(
      name: T.nilable(String),
      to_invoke: T.any(Symbol, Proc),
      description: T.nilable(String),
      raw_args: T::Boolean,
      unfinished_policy: Integer,
      validator_to_invoke: T.nilable(T.any(Symbol, Proc)),
      arg_hints: T.nilable(T::Array[Object]),
      result_hint: T.nilable(Object)
    ).void
  end
  def initialize(
    name:,
    to_invoke:,
    description: T.unsafe(nil),
    raw_args: T.unsafe(nil),
    unfinished_policy: T.unsafe(nil),
    validator_to_invoke: T.unsafe(nil),
    arg_hints: T.unsafe(nil),
    result_hint: T.unsafe(nil)
  ); end
end

# ============================================================
# Temporalio::Workflow::Info
# ============================================================

class Temporalio::Workflow::Info < ::Struct
  extend T::Sig

  sig { returns(Integer) }
  def attempt; end

  sig { returns(T.nilable(String)) }
  def continued_run_id; end

  sig { returns(T.nilable(String)) }
  def cron_schedule; end

  sig { returns(T.nilable(Float)) }
  def execution_timeout; end

  sig { returns(String) }
  def first_execution_run_id; end

  sig { returns(T::Hash[String, T.untyped]) }
  def headers; end

  sig { returns(T.nilable(Exception)) }
  def last_failure; end

  sig { returns(T.nilable(Object)) }
  def last_result; end

  sig { returns(T::Boolean) }
  def has_last_result?; end

  sig { returns(String) }
  def namespace; end

  sig { returns(T.nilable(Temporalio::Workflow::Info::ParentInfo)) }
  def parent; end

  sig { returns(Temporalio::Priority) }
  def priority; end

  sig { returns(T.nilable(Temporalio::RetryPolicy)) }
  def retry_policy; end

  sig { returns(T.nilable(Temporalio::Workflow::Info::RootInfo)) }
  def root; end

  sig { returns(String) }
  def run_id; end

  sig { returns(T.nilable(Float)) }
  def run_timeout; end

  sig { returns(Time) }
  def start_time; end

  sig { returns(String) }
  def task_queue; end

  sig { returns(Float) }
  def task_timeout; end

  sig { returns(String) }
  def workflow_id; end

  sig { returns(String) }
  def workflow_type; end

  sig { returns(T::Hash[Symbol, T.untyped]) }
  def to_h; end
end

class Temporalio::Workflow::Info::ParentInfo < ::Struct
  extend T::Sig

  sig { returns(String) }
  def namespace; end

  sig { returns(String) }
  def run_id; end

  sig { returns(String) }
  def workflow_id; end

  sig { returns(T::Hash[Symbol, T.untyped]) }
  def to_h; end
end

class Temporalio::Workflow::Info::RootInfo < ::Struct
  extend T::Sig

  sig { returns(String) }
  def run_id; end

  sig { returns(String) }
  def workflow_id; end

  sig { returns(T::Hash[Symbol, T.untyped]) }
  def to_h; end
end

# ============================================================
# Temporalio::Workflow::UpdateInfo
# ============================================================

class Temporalio::Workflow::UpdateInfo < ::Struct
  extend T::Sig

  sig { returns(String) }
  def id; end

  sig { returns(String) }
  def name; end

  sig { returns(T::Hash[Symbol, T.untyped]) }
  def to_h; end
end

# ============================================================
# Temporalio::Workflow::Future
# ============================================================

class Temporalio::Workflow::Future
  extend T::Sig

  Elem = type_member

  sig { returns(T.nilable(Elem)) }
  def result; end

  sig { returns(T.nilable(Exception)) }
  def failure; end

  sig { params(block: T.nilable(T.proc.returns(Elem))).void }
  def initialize(&block); end

  sig { returns(T::Boolean) }
  def done?; end

  sig { returns(T::Boolean) }
  def result?; end

  sig { params(result: Elem).void }
  def result=(result); end

  sig { returns(T::Boolean) }
  def failure?; end

  sig { params(failure: Exception).void }
  def failure=(failure); end

  sig { returns(Elem) }
  def wait; end

  sig { returns(T.nilable(Elem)) }
  def wait_no_raise; end

  class << self
    extend T::Sig

    sig { params(futures: Temporalio::Workflow::Future[T.untyped]).returns(Temporalio::Workflow::Future[NilClass]) }
    def all_of(*futures); end

    sig do
      type_parameters(:T)
        .params(futures: Temporalio::Workflow::Future[T.type_parameter(:T)])
        .returns(Temporalio::Workflow::Future[T.type_parameter(:T)])
    end
    def any_of(*futures); end

    sig do
      type_parameters(:T)
        .params(futures: Temporalio::Workflow::Future[T.type_parameter(:T)])
        .returns(Temporalio::Workflow::Future[Temporalio::Workflow::Future[T.type_parameter(:T)]])
    end
    def try_any_of(*futures); end

    sig { params(futures: Temporalio::Workflow::Future[T.untyped]).returns(Temporalio::Workflow::Future[NilClass]) }
    def try_all_of(*futures); end
  end
end

# ============================================================
# Temporalio::Workflow::ChildWorkflowHandle
# ============================================================

class Temporalio::Workflow::ChildWorkflowHandle
  extend T::Sig

  sig { returns(String) }
  def id; end

  sig { returns(String) }
  def first_execution_run_id; end

  sig { returns(T.nilable(Object)) }
  def result_hint; end

  sig { params(result_hint: T.nilable(Object)).returns(T.nilable(Object)) }
  def result(result_hint: T.unsafe(nil)); end

  sig do
    params(
      signal: T.any(Temporalio::Workflow::Definition::Signal, Symbol, String),
      args: T.nilable(Object),
      cancellation: Temporalio::Cancellation,
      arg_hints: T.nilable(T::Array[Object])
    ).void
  end
  def signal(signal, *args, cancellation: T.unsafe(nil), arg_hints: T.unsafe(nil)); end
end

# ============================================================
# Temporalio::Workflow::ExternalWorkflowHandle
# ============================================================

class Temporalio::Workflow::ExternalWorkflowHandle
  extend T::Sig

  sig { returns(String) }
  def id; end

  sig { returns(T.nilable(String)) }
  def run_id; end

  sig do
    params(
      signal: T.any(Temporalio::Workflow::Definition::Signal, Symbol, String),
      args: T.nilable(Object),
      cancellation: Temporalio::Cancellation,
      arg_hints: T.nilable(T::Array[Object])
    ).void
  end
  def signal(signal, *args, cancellation: T.unsafe(nil), arg_hints: T.unsafe(nil)); end

  sig { void }
  def cancel; end
end

# ============================================================
# Temporalio::Workflow::NexusClient
# ============================================================

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

# ============================================================
# Temporalio::Workflow::NexusOperationHandle
# ============================================================

class Temporalio::Workflow::NexusOperationHandle
  extend T::Sig

  sig { returns(T.nilable(String)) }
  def operation_token; end

  sig { returns(T.nilable(Object)) }
  def result_hint; end

  sig { params(result_hint: T.nilable(Object)).returns(T.nilable(Object)) }
  def result(result_hint: T.unsafe(nil)); end
end

# ============================================================
# Workflow enum modules
# ============================================================

module Temporalio::Workflow::ActivityCancellationType
  TRY_CANCEL = T.let(T.unsafe(nil), Integer)
  WAIT_CANCELLATION_COMPLETED = T.let(T.unsafe(nil), Integer)
  ABANDON = T.let(T.unsafe(nil), Integer)
end

module Temporalio::Workflow::ChildWorkflowCancellationType
  ABANDON = T.let(T.unsafe(nil), Integer)
  TRY_CANCEL = T.let(T.unsafe(nil), Integer)
  WAIT_CANCELLATION_COMPLETED = T.let(T.unsafe(nil), Integer)
  WAIT_CANCELLATION_REQUESTED = T.let(T.unsafe(nil), Integer)
end

module Temporalio::Workflow::HandlerUnfinishedPolicy
  WARN_AND_ABANDON = T.let(T.unsafe(nil), Integer)
  ABANDON = T.let(T.unsafe(nil), Integer)
end

module Temporalio::Workflow::ParentClosePolicy
  UNSPECIFIED = T.let(T.unsafe(nil), Integer)
  TERMINATE = T.let(T.unsafe(nil), Integer)
  ABANDON = T.let(T.unsafe(nil), Integer)
  REQUEST_CANCEL = T.let(T.unsafe(nil), Integer)
end

module Temporalio::Workflow::NexusOperationCancellationType
  WAIT_CANCELLATION_COMPLETED = T.let(T.unsafe(nil), Integer)
  ABANDON = T.let(T.unsafe(nil), Integer)
  TRY_CANCEL = T.let(T.unsafe(nil), Integer)
  WAIT_CANCELLATION_REQUESTED = T.let(T.unsafe(nil), Integer)
end

# Workflow error types
class Temporalio::Workflow::ContinueAsNewError < ::Temporalio::Error
  extend T::Sig

  sig do
    params(
      args: T.nilable(Object),
      workflow: T.nilable(T.any(T.class_of(Temporalio::Workflow::Definition), String, Symbol)),
      task_queue: T.nilable(String),
      run_timeout: T.nilable(T.any(Integer, Float)),
      task_timeout: T.nilable(T.any(Integer, Float)),
      retry_policy: T.nilable(Temporalio::RetryPolicy),
      memo: T.nilable(T::Hash[T.any(String, Symbol), T.nilable(Object)]),
      search_attributes: T.nilable(Temporalio::SearchAttributes),
      arg_hints: T.nilable(T::Array[Object]),
      headers: T::Hash[String, T.nilable(Object)],
      initial_versioning_behavior: T.nilable(Integer)
    ).void
  end
  def initialize(
    *args,
    workflow: T.unsafe(nil),
    task_queue: T.unsafe(nil),
    run_timeout: T.unsafe(nil),
    task_timeout: T.unsafe(nil),
    retry_policy: T.unsafe(nil),
    memo: T.unsafe(nil),
    search_attributes: T.unsafe(nil),
    arg_hints: T.unsafe(nil),
    headers: T.unsafe(nil),
    initial_versioning_behavior: T.unsafe(nil)
  ); end

  sig { returns(T::Array[T.nilable(Object)]) }
  def args; end

  sig { params(value: T::Array[T.nilable(Object)]).void }
  def args=(value); end

  sig { returns(T.nilable(T.any(T.class_of(Temporalio::Workflow::Definition), String, Symbol))) }
  def workflow; end

  sig { params(value: T.nilable(T.any(T.class_of(Temporalio::Workflow::Definition), String, Symbol))).void }
  def workflow=(value); end

  sig { returns(T.nilable(String)) }
  def task_queue; end

  sig { params(value: T.nilable(String)).void }
  def task_queue=(value); end

  sig { returns(T.nilable(T.any(Integer, Float))) }
  def run_timeout; end

  sig { params(value: T.nilable(T.any(Integer, Float))).void }
  def run_timeout=(value); end

  sig { returns(T.nilable(T.any(Integer, Float))) }
  def task_timeout; end

  sig { params(value: T.nilable(T.any(Integer, Float))).void }
  def task_timeout=(value); end

  sig { returns(T.nilable(Temporalio::RetryPolicy)) }
  def retry_policy; end

  sig { params(value: T.nilable(Temporalio::RetryPolicy)).void }
  def retry_policy=(value); end

  sig { returns(T.nilable(T::Hash[T.any(String, Symbol), T.nilable(Object)])) }
  def memo; end

  sig { params(value: T.nilable(T::Hash[T.any(String, Symbol), T.nilable(Object)])).void }
  def memo=(value); end

  sig { returns(T.nilable(Temporalio::SearchAttributes)) }
  def search_attributes; end

  sig { params(value: T.nilable(Temporalio::SearchAttributes)).void }
  def search_attributes=(value); end

  sig { returns(T.nilable(T::Array[Object])) }
  def arg_hints; end

  sig { params(value: T.nilable(T::Array[Object])).void }
  def arg_hints=(value); end

  sig { returns(T::Hash[String, T.nilable(Object)]) }
  def headers; end

  sig { params(value: T::Hash[String, T.nilable(Object)]).void }
  def headers=(value); end

  sig { returns(T.nilable(Integer)) }
  def initial_versioning_behavior; end

  sig { params(value: T.nilable(Integer)).void }
  def initial_versioning_behavior=(value); end
end

class Temporalio::Workflow::InvalidWorkflowStateError < ::Temporalio::Error; end
class Temporalio::Workflow::NondeterminismError < ::Temporalio::Error; end

# ============================================================
# Temporalio::Runtime
# ============================================================

class Temporalio::Runtime
  extend T::Sig

  sig { returns(Temporalio::Metric::Meter) }
  def metric_meter; end

  sig { params(telemetry: Temporalio::Runtime::TelemetryOptions, worker_heartbeat_interval: T.nilable(Float)).void }
  def initialize(telemetry: T.unsafe(nil), worker_heartbeat_interval: T.unsafe(nil)); end

  class << self
    extend T::Sig

    sig { returns(Temporalio::Runtime) }
    def default; end

    sig { params(runtime: Temporalio::Runtime).void }
    def default=(runtime); end
  end
end

class Temporalio::Runtime::TelemetryOptions < ::Data
  extend T::Sig

  sig { returns(T.nilable(Temporalio::Runtime::LoggingOptions)) }
  def logging; end

  sig { returns(T.nilable(Temporalio::Runtime::MetricsOptions)) }
  def metrics; end

  sig { params(logging: T.nilable(Temporalio::Runtime::LoggingOptions), metrics: T.nilable(Temporalio::Runtime::MetricsOptions)).void }
  def initialize(logging: T.unsafe(nil), metrics: T.unsafe(nil)); end
end

class Temporalio::Runtime::LoggingOptions < ::Data
  extend T::Sig

  sig { returns(T.any(Temporalio::Runtime::LoggingFilterOptions, String)) }
  def log_filter; end

  sig { params(log_filter: T.any(Temporalio::Runtime::LoggingFilterOptions, String)).void }
  def initialize(log_filter: T.unsafe(nil)); end
end

class Temporalio::Runtime::LoggingFilterOptions < ::Data
  extend T::Sig

  sig { returns(String) }
  def core_level; end

  sig { returns(String) }
  def other_level; end

  sig { params(core_level: String, other_level: String).void }
  def initialize(core_level: T.unsafe(nil), other_level: T.unsafe(nil)); end
end

class Temporalio::Runtime::MetricsOptions < ::Data
  extend T::Sig

  sig { returns(T.nilable(Temporalio::Runtime::OpenTelemetryMetricsOptions)) }
  def opentelemetry; end

  sig { returns(T.nilable(Temporalio::Runtime::PrometheusMetricsOptions)) }
  def prometheus; end

  sig { returns(T.nilable(Temporalio::Runtime::MetricBuffer)) }
  def buffer; end

  sig { returns(T::Boolean) }
  def attach_service_name; end

  sig { returns(T.nilable(T::Hash[String, String])) }
  def global_tags; end

  sig { returns(T.nilable(String)) }
  def metric_prefix; end

  sig do
    params(
      opentelemetry: T.nilable(Temporalio::Runtime::OpenTelemetryMetricsOptions),
      prometheus: T.nilable(Temporalio::Runtime::PrometheusMetricsOptions),
      buffer: T.nilable(Temporalio::Runtime::MetricBuffer),
      attach_service_name: T::Boolean,
      global_tags: T.nilable(T::Hash[String, String]),
      metric_prefix: T.nilable(String)
    ).void
  end
  def initialize(
    opentelemetry: T.unsafe(nil),
    prometheus: T.unsafe(nil),
    buffer: T.unsafe(nil),
    attach_service_name: T.unsafe(nil),
    global_tags: T.unsafe(nil),
    metric_prefix: T.unsafe(nil)
  ); end
end

class Temporalio::Runtime::OpenTelemetryMetricsOptions < ::Data
  extend T::Sig

  sig { returns(String) }
  def url; end

  sig { returns(T.nilable(T::Hash[String, String])) }
  def headers; end

  sig { returns(T.nilable(Float)) }
  def metric_periodicity; end

  sig { returns(Integer) }
  def metric_temporality; end

  sig { returns(T::Boolean) }
  def durations_as_seconds; end

  sig { returns(T::Boolean) }
  def http; end

  sig { returns(T.nilable(T::Hash[String, T::Array[Numeric]])) }
  def histogram_bucket_overrides; end

  sig do
    params(
      url: String,
      headers: T.nilable(T::Hash[String, String]),
      metric_periodicity: T.nilable(Float),
      metric_temporality: Integer,
      durations_as_seconds: T::Boolean,
      http: T::Boolean,
      histogram_bucket_overrides: T.nilable(T::Hash[String, T::Array[Numeric]])
    ).void
  end
  def initialize(
    url:,
    headers: T.unsafe(nil),
    metric_periodicity: T.unsafe(nil),
    metric_temporality: T.unsafe(nil),
    durations_as_seconds: T.unsafe(nil),
    http: T.unsafe(nil),
    histogram_bucket_overrides: T.unsafe(nil)
  ); end

  module MetricTemporality
    CUMULATIVE = T.let(T.unsafe(nil), Integer)
    DELTA = T.let(T.unsafe(nil), Integer)
  end
end

class Temporalio::Runtime::PrometheusMetricsOptions < ::Data
  extend T::Sig

  sig { returns(String) }
  def bind_address; end

  sig { returns(T::Boolean) }
  def counters_total_suffix; end

  sig { returns(T::Boolean) }
  def unit_suffix; end

  sig { returns(T::Boolean) }
  def durations_as_seconds; end

  sig { returns(T.nilable(T::Hash[String, T::Array[Numeric]])) }
  def histogram_bucket_overrides; end

  sig do
    params(
      bind_address: String,
      counters_total_suffix: T::Boolean,
      unit_suffix: T::Boolean,
      durations_as_seconds: T::Boolean,
      histogram_bucket_overrides: T.nilable(T::Hash[String, T::Array[Numeric]])
    ).void
  end
  def initialize(
    bind_address:,
    counters_total_suffix: T.unsafe(nil),
    unit_suffix: T.unsafe(nil),
    durations_as_seconds: T.unsafe(nil),
    histogram_bucket_overrides: T.unsafe(nil)
  ); end
end

# ============================================================
# Temporalio::Runtime::MetricBuffer
# ============================================================

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

# ============================================================
# Temporalio::Converters::DataConverter
# ============================================================

module Temporalio::Converters; end

class Temporalio::Converters::DataConverter
  extend T::Sig

  sig { returns(Temporalio::Converters::PayloadConverter) }
  def payload_converter; end

  sig { returns(Temporalio::Converters::FailureConverter) }
  def failure_converter; end

  sig { returns(T.nilable(Temporalio::Converters::PayloadCodec)) }
  def payload_codec; end

  sig { returns(Temporalio::Converters::DataConverter) }
  def self.default; end

  sig do
    params(
      payload_converter: Temporalio::Converters::PayloadConverter,
      failure_converter: Temporalio::Converters::FailureConverter,
      payload_codec: T.nilable(Temporalio::Converters::PayloadCodec)
    ).void
  end
  def initialize(payload_converter: T.unsafe(nil), failure_converter: T.unsafe(nil), payload_codec: T.unsafe(nil)); end

  sig { params(value: T.nilable(Object), hint: T.nilable(Object)).returns(T.untyped) }
  def to_payload(value, hint: T.unsafe(nil)); end

  sig { params(values: T::Array[T.nilable(Object)], hints: T.nilable(T::Array[Object])).returns(T.untyped) }
  def to_payloads(values, hints: T.unsafe(nil)); end

  sig { params(payload: T.untyped, hint: T.nilable(Object)).returns(T.nilable(Object)) }
  def from_payload(payload, hint: T.unsafe(nil)); end

  sig { params(payloads: T.untyped, hints: T.nilable(T::Array[Object])).returns(T::Array[T.nilable(Object)]) }
  def from_payloads(payloads, hints: T.unsafe(nil)); end

  sig { params(error: Exception).returns(T.untyped) }
  def to_failure(error); end

  sig { params(failure: T.untyped).returns(Exception) }
  def from_failure(failure); end
end

# ============================================================
# Temporalio::Converters::FailureConverter
# ============================================================

class Temporalio::Converters::FailureConverter
  extend T::Sig

  sig { returns(Temporalio::Converters::FailureConverter) }
  def self.default; end

  sig { params(encode_common_attributes: T::Boolean).void }
  def initialize(encode_common_attributes: T.unsafe(nil)); end

  sig { returns(T::Boolean) }
  def encode_common_attributes; end

  sig { params(error: Exception, converter: T.any(Temporalio::Converters::DataConverter, Temporalio::Converters::PayloadConverter)).returns(T.untyped) }
  def to_failure(error, converter); end

  sig { params(failure: T.untyped, converter: T.any(Temporalio::Converters::DataConverter, Temporalio::Converters::PayloadConverter)).returns(Exception) }
  def from_failure(failure, converter); end
end

# ============================================================
# Temporalio::Converters::PayloadCodec
# ============================================================

class Temporalio::Converters::PayloadCodec
  extend T::Sig

  sig { params(payloads: T::Enumerable[T.untyped]).returns(T::Array[T.untyped]) }
  def encode(payloads); end

  sig { params(payloads: T::Enumerable[T.untyped]).returns(T::Array[T.untyped]) }
  def decode(payloads); end
end

# ============================================================
# Temporalio::Converters::PayloadConverter
# ============================================================

class Temporalio::Converters::PayloadConverter
  extend T::Sig

  sig { returns(Temporalio::Converters::PayloadConverter::Composite) }
  def self.default; end

  sig do
    params(
      json_parse_options: T::Hash[Symbol, T.untyped],
      json_generate_options: T::Hash[Symbol, T.untyped]
    ).returns(Temporalio::Converters::PayloadConverter::Composite)
  end
  def self.new_with_defaults(json_parse_options: T.unsafe(nil), json_generate_options: T.unsafe(nil)); end

  sig { params(value: T.nilable(Object), hint: T.nilable(Object)).returns(T.untyped) }
  def to_payload(value, hint: T.unsafe(nil)); end

  sig { params(values: T::Array[T.nilable(Object)], hints: T.nilable(T::Array[Object])).returns(T.untyped) }
  def to_payloads(values, hints: T.unsafe(nil)); end

  sig { params(payload: T.untyped, hint: T.nilable(Object)).returns(T.nilable(Object)) }
  def from_payload(payload, hint: T.unsafe(nil)); end

  sig { params(payloads: T.untyped, hints: T.nilable(T::Array[Object])).returns(T::Array[T.nilable(Object)]) }
  def from_payloads(payloads, hints: T.unsafe(nil)); end
end

class Temporalio::Converters::PayloadConverter::Composite < ::Temporalio::Converters::PayloadConverter
  extend T::Sig

  sig { returns(T::Hash[String, Temporalio::Converters::PayloadConverter::Encoding]) }
  def converters; end

  sig { params(converters: Temporalio::Converters::PayloadConverter::Encoding).void }
  def initialize(*converters); end

  sig { params(value: T.nilable(Object), hint: T.nilable(Object)).returns(T.untyped) }
  def to_payload(value, hint: T.unsafe(nil)); end

  sig { params(payload: T.untyped, hint: T.nilable(Object)).returns(T.nilable(Object)) }
  def from_payload(payload, hint: T.unsafe(nil)); end

  class ConverterNotFound < ::Temporalio::Error; end
  class EncodingNotSet < ::Temporalio::Error; end
end

class Temporalio::Converters::PayloadConverter::Encoding
  extend T::Sig

  sig { returns(String) }
  def encoding; end

  sig { params(value: T.nilable(Object), hint: T.nilable(Object)).returns(T.untyped) }
  def to_payload(value, hint: T.unsafe(nil)); end

  sig { params(payload: T.untyped, hint: T.nilable(Object)).returns(T.nilable(Object)) }
  def from_payload(payload, hint: T.unsafe(nil)); end
end

class Temporalio::Converters::PayloadConverter::BinaryNull < ::Temporalio::Converters::PayloadConverter::Encoding
  ENCODING = T.let(T.unsafe(nil), String)
end

class Temporalio::Converters::PayloadConverter::BinaryPlain < ::Temporalio::Converters::PayloadConverter::Encoding
  ENCODING = T.let(T.unsafe(nil), String)
end

class Temporalio::Converters::PayloadConverter::BinaryProtobuf < ::Temporalio::Converters::PayloadConverter::Encoding
  ENCODING = T.let(T.unsafe(nil), String)
end

class Temporalio::Converters::PayloadConverter::JSONPlain < ::Temporalio::Converters::PayloadConverter::Encoding
  extend T::Sig

  ENCODING = T.let(T.unsafe(nil), String)

  sig { params(parse_options: T::Hash[Symbol, T.untyped], generate_options: T::Hash[Symbol, T.untyped]).void }
  def initialize(parse_options: T.unsafe(nil), generate_options: T.unsafe(nil)); end
end

class Temporalio::Converters::PayloadConverter::JSONProtobuf < ::Temporalio::Converters::PayloadConverter::Encoding
  ENCODING = T.let(T.unsafe(nil), String)
end

class Temporalio::Converters::RawValue
  extend T::Sig

  sig { returns(T.untyped) }
  def payload; end

  sig { params(payload: T.untyped).void }
  def initialize(payload); end
end

# ============================================================
# Temporalio::Contrib::OpenTelemetry
# ============================================================

module Temporalio::Contrib; end
module Temporalio::Contrib::OpenTelemetry; end

class Temporalio::Contrib::OpenTelemetry::TracingInterceptor
  include Temporalio::Client::Interceptor
  include Temporalio::Worker::Interceptor::Activity
  include Temporalio::Worker::Interceptor::Workflow

  extend T::Sig

  sig { returns(T.untyped) }
  def tracer; end

  sig do
    params(
      tracer: T.untyped,
      header_key: String,
      propagator: T.untyped,
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
          attributes: T::Hash[T.untyped, T.untyped],
          links: T.nilable(T::Array[T.untyped]),
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
        attributes: T::Hash[T.untyped, T.untyped],
        links: T.nilable(T::Array[T.untyped]),
        kind: T.nilable(Symbol),
        exception: T.nilable(Exception),
        even_during_replay: T::Boolean
      ).returns(T.untyped)
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

# ============================================================
# Temporalio::EnvConfig
# ============================================================

module Temporalio::EnvConfig; end

class Temporalio::EnvConfig::ClientConfigTLS < ::Data
  extend T::Sig

  sig { returns(T.nilable(T::Boolean)) }
  def disabled; end

  sig { returns(T.nilable(String)) }
  def server_name; end

  sig { returns(T.nilable(T.any(Pathname, String))) }
  def server_root_ca_cert; end

  sig { returns(T.nilable(T.any(Pathname, String))) }
  def client_cert; end

  sig { returns(T.nilable(T.any(Pathname, String))) }
  def client_private_key; end

  sig do
    params(
      disabled: T.nilable(T::Boolean),
      server_name: T.nilable(String),
      server_root_ca_cert: T.nilable(T.any(Pathname, String)),
      client_cert: T.nilable(T.any(Pathname, String)),
      client_private_key: T.nilable(T.any(Pathname, String))
    ).void
  end
  def initialize(
    disabled: T.unsafe(nil),
    server_name: T.unsafe(nil),
    server_root_ca_cert: T.unsafe(nil),
    client_cert: T.unsafe(nil),
    client_private_key: T.unsafe(nil)
  ); end

  sig { returns(T::Hash[Symbol, T.untyped]) }
  def to_h; end

  sig { returns(T.untyped) }
  def to_client_tls_options; end

  sig { params(hash: T.nilable(T::Hash[T.untyped, T.untyped])).returns(T.nilable(Temporalio::EnvConfig::ClientConfigTLS)) }
  def self.from_h(hash); end
end

class Temporalio::EnvConfig::ClientConfigProfile < ::Data
  extend T::Sig

  sig { returns(T.nilable(String)) }
  def address; end

  sig { returns(T.nilable(String)) }
  def namespace; end

  sig { returns(T.nilable(String)) }
  def api_key; end

  sig { returns(T.nilable(Temporalio::EnvConfig::ClientConfigTLS)) }
  def tls; end

  sig { returns(T::Hash[T.untyped, T.untyped]) }
  def grpc_meta; end

  sig do
    params(
      address: T.nilable(String),
      namespace: T.nilable(String),
      api_key: T.nilable(String),
      tls: T.nilable(Temporalio::EnvConfig::ClientConfigTLS),
      grpc_meta: T::Hash[T.untyped, T.untyped]
    ).void
  end
  def initialize(
    address: T.unsafe(nil),
    namespace: T.unsafe(nil),
    api_key: T.unsafe(nil),
    tls: T.unsafe(nil),
    grpc_meta: T.unsafe(nil)
  ); end

  sig { params(hash: T::Hash[T.untyped, T.untyped]).returns(Temporalio::EnvConfig::ClientConfigProfile) }
  def self.from_h(hash); end

  sig do
    params(
      profile: T.nilable(String),
      config_source: T.nilable(T.any(Pathname, String)),
      disable_file: T::Boolean,
      disable_env: T::Boolean,
      config_file_strict: T::Boolean,
      override_env_vars: T.nilable(T::Hash[String, String])
    ).returns(Temporalio::EnvConfig::ClientConfigProfile)
  end
  def self.load(
    profile: T.unsafe(nil),
    config_source: T.unsafe(nil),
    disable_file: T.unsafe(nil),
    disable_env: T.unsafe(nil),
    config_file_strict: T.unsafe(nil),
    override_env_vars: T.unsafe(nil)
  ); end

  sig { returns(T::Hash[Symbol, T.untyped]) }
  def to_h; end

  sig { returns([T::Array[T.untyped], T::Hash[Symbol, T.untyped]]) }
  def to_client_connect_options; end
end

class Temporalio::EnvConfig::ClientConfig < ::Data
  extend T::Sig

  sig { returns(T::Hash[String, Temporalio::EnvConfig::ClientConfigProfile]) }
  def profiles; end

  sig { params(profiles: T::Hash[String, Temporalio::EnvConfig::ClientConfigProfile]).void }
  def initialize(profiles: T.unsafe(nil)); end

  sig { params(hash: T::Hash[T.untyped, T.untyped]).returns(Temporalio::EnvConfig::ClientConfig) }
  def self.from_h(hash); end

  sig do
    params(
      config_source: T.nilable(T.any(Pathname, String)),
      config_file_strict: T::Boolean,
      override_env_vars: T.nilable(T::Hash[String, String])
    ).returns(Temporalio::EnvConfig::ClientConfig)
  end
  def self.load(config_source: T.unsafe(nil), config_file_strict: T.unsafe(nil), override_env_vars: T.unsafe(nil)); end

  sig do
    params(
      profile: T.nilable(String),
      config_source: T.nilable(T.any(Pathname, String)),
      disable_file: T::Boolean,
      disable_env: T::Boolean,
      config_file_strict: T::Boolean,
      override_env_vars: T.nilable(T::Hash[String, String])
    ).returns([T::Array[T.untyped], T::Hash[Symbol, T.untyped]])
  end
  def self.load_client_connect_options(
    profile: T.unsafe(nil),
    config_source: T.unsafe(nil),
    disable_file: T.unsafe(nil),
    disable_env: T.unsafe(nil),
    config_file_strict: T.unsafe(nil),
    override_env_vars: T.unsafe(nil)
  ); end

  sig { returns(T::Hash[String, T::Hash[Symbol, T.untyped]]) }
  def to_h; end
end

# ============================================================
# Temporalio::Testing
# ============================================================

module Temporalio::Testing; end

class Temporalio::Testing::ActivityEnvironment
  extend T::Sig

  sig { returns(Temporalio::Activity::Info) }
  def self.default_info; end

  sig do
    params(
      info: Temporalio::Activity::Info,
      on_heartbeat: T.nilable(Proc),
      cancellation: Temporalio::Cancellation,
      on_cancellation_details: T.nilable(Proc),
      worker_shutdown_cancellation: Temporalio::Cancellation,
      payload_converter: Temporalio::Converters::PayloadConverter,
      logger: Logger,
      activity_executors: T::Hash[Symbol, Temporalio::Worker::ActivityExecutor],
      metric_meter: T.nilable(Temporalio::Metric::Meter),
      client: T.nilable(Temporalio::Client)
    ).void
  end
  def initialize(
    info: T.unsafe(nil),
    on_heartbeat: T.unsafe(nil),
    cancellation: T.unsafe(nil),
    on_cancellation_details: T.unsafe(nil),
    worker_shutdown_cancellation: T.unsafe(nil),
    payload_converter: T.unsafe(nil),
    logger: T.unsafe(nil),
    activity_executors: T.unsafe(nil),
    metric_meter: T.unsafe(nil),
    client: T.unsafe(nil)
  ); end

  sig do
    params(
      activity: T.any(Temporalio::Activity::Definition, T.class_of(Temporalio::Activity::Definition), Temporalio::Activity::Definition::Info),
      args: T.nilable(Object)
    ).returns(T.untyped)
  end
  def run(activity, *args); end
end

class Temporalio::Testing::WorkflowEnvironment
  extend T::Sig

  sig { returns(Temporalio::Client) }
  def client; end

  sig { params(client: Temporalio::Client).void }
  def initialize(client); end

  sig { void }
  def shutdown; end

  sig { returns(T::Boolean) }
  def supports_time_skipping?; end

  sig { params(duration: T.any(Integer, Float)).void }
  def sleep(duration); end

  sig { returns(Time) }
  def current_time; end

  sig { params(name: String, task_queue: String).returns(T.untyped) }
  def create_nexus_endpoint(name:, task_queue:); end

  sig { params(endpoint: T.untyped).returns(NilClass) }
  def delete_nexus_endpoint(endpoint); end

  sig { type_parameters(:T).params(block: T.proc.returns(T.type_parameter(:T))).returns(T.type_parameter(:T)) }
  def auto_time_skipping_disabled(&block); end

  class << self
    extend T::Sig

    sig do
      params(
        namespace: String,
        data_converter: Temporalio::Converters::DataConverter,
        interceptors: T::Array[Temporalio::Client::Interceptor],
        logger: Logger,
        default_workflow_query_reject_condition: T.nilable(Integer),
        ip: String,
        port: T.nilable(Integer),
        ui: T::Boolean,
        ui_port: T.nilable(Integer),
        search_attributes: T::Array[Temporalio::SearchAttributes::Key],
        runtime: Temporalio::Runtime,
        dev_server_existing_path: T.nilable(String),
        dev_server_database_filename: T.nilable(String),
        dev_server_log_format: String,
        dev_server_log_level: String,
        dev_server_download_version: String,
        dev_server_download_dest_dir: T.nilable(String),
        dev_server_extra_args: T::Array[String],
        dev_server_download_ttl: T.nilable(Float)
      ).returns(Temporalio::Testing::WorkflowEnvironment)
    end
    def start_local(
      namespace: T.unsafe(nil),
      data_converter: T.unsafe(nil),
      interceptors: T.unsafe(nil),
      logger: T.unsafe(nil),
      default_workflow_query_reject_condition: T.unsafe(nil),
      ip: T.unsafe(nil),
      port: T.unsafe(nil),
      ui: T.unsafe(nil),
      ui_port: T.unsafe(nil),
      search_attributes: T.unsafe(nil),
      runtime: T.unsafe(nil),
      dev_server_existing_path: T.unsafe(nil),
      dev_server_database_filename: T.unsafe(nil),
      dev_server_log_format: T.unsafe(nil),
      dev_server_log_level: T.unsafe(nil),
      dev_server_download_version: T.unsafe(nil),
      dev_server_download_dest_dir: T.unsafe(nil),
      dev_server_extra_args: T.unsafe(nil),
      dev_server_download_ttl: T.unsafe(nil)
    ); end

    sig do
      params(
        data_converter: Temporalio::Converters::DataConverter,
        interceptors: T::Array[Temporalio::Client::Interceptor],
        logger: Logger,
        default_workflow_query_reject_condition: T.nilable(Integer),
        port: T.nilable(Integer),
        runtime: Temporalio::Runtime,
        test_server_existing_path: T.nilable(String),
        test_server_download_version: String,
        test_server_download_dest_dir: T.nilable(String),
        test_server_extra_args: T::Array[String],
        test_server_download_ttl: T.nilable(Float)
      ).returns(Temporalio::Testing::WorkflowEnvironment)
    end
    def start_time_skipping(
      data_converter: T.unsafe(nil),
      interceptors: T.unsafe(nil),
      logger: T.unsafe(nil),
      default_workflow_query_reject_condition: T.unsafe(nil),
      port: T.unsafe(nil),
      runtime: T.unsafe(nil),
      test_server_existing_path: T.unsafe(nil),
      test_server_download_version: T.unsafe(nil),
      test_server_download_dest_dir: T.unsafe(nil),
      test_server_extra_args: T.unsafe(nil),
      test_server_download_ttl: T.unsafe(nil)
    ); end
  end
end

# ============================================================
# Temporalio::SimplePlugin
# ============================================================

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

# ============================================================
# Temporalio::Workflow::Mutex, Queue, SizedQueue
# ============================================================

class Temporalio::Workflow::Mutex < ::Mutex; end
class Temporalio::Workflow::Queue < ::Queue; end
class Temporalio::Workflow::SizedQueue < ::SizedQueue; end
