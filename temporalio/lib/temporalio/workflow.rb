# frozen_string_literal: true

require 'random/formatter'
require 'temporalio/error'
require 'temporalio/priority'
require 'temporalio/workflow/activity_cancellation_type'
require 'temporalio/workflow/child_workflow_cancellation_type'
require 'temporalio/workflow/child_workflow_handle'
require 'temporalio/workflow/definition'
require 'temporalio/workflow/external_workflow_handle'
require 'temporalio/workflow/future'
require 'temporalio/workflow/handler_unfinished_policy'
require 'temporalio/workflow/info'
require 'temporalio/workflow/parent_close_policy'
require 'temporalio/workflow/update_info'
require 'timeout'

module Temporalio
  # Module with all class-methods that can be made from a workflow. Methods on this module cannot be used outside of a
  # workflow with the obvious exception of {in_workflow?}. This module is not meant to be included or mixed in.
  module Workflow
    # @return [Boolean] Whether all update and signal handlers have finished executing. Consider waiting on this
    #   condition before workflow return or continue-as-new, to prevent interruption of in-progress handlers by workflow
    #   return: `Temporalio::Workflow.wait_condition { Temporalio::Workflow.all_handlers_finished? }``
    def self.all_handlers_finished?
      _current.all_handlers_finished?
    end

    # @return [Cancellation] Cancellation for the workflow. This is canceled when a workflow cancellation request is
    #   received. This is the default cancellation for most workflow calls.
    def self.cancellation
      _current.cancellation
    end

    # @return [Boolean] Whether continue as new is suggested. This value is the current continue-as-new suggestion up
    #   until the current task. Note, this value may not be up to date when accessed in a query. When continue as new is
    #   suggested is based on server-side configuration.
    def self.continue_as_new_suggested
      _current.continue_as_new_suggested
    end

    # Get current details for this workflow that may appear in UI/CLI. Unlike static details set at start, this value
    # can be updated throughout the life of the workflow. This can be in Temporal markdown format and can span multiple
    # lines. This is currently experimental.
    #
    # @return [String] Current details. Default is empty string.
    def self.current_details
      _current.current_details
    end

    # Set current details for this workflow that may appear in UI/CLI. Unlike static details set at start, this value
    # can be updated throughout the life of the workflow. This can be in Temporal markdown format and can span multiple
    # lines. This is currently experimental.
    #
    # @param details [String] Current details. Can use empty string to unset.
    def self.current_details=(details)
      _current.current_details = details
    end

    # Get the deployment version of the worker which executed the current Workflow Task.
    #
    # May be nil if the task was completed by a worker without a deployment version or build id. If
    # this worker is the one executing this task for the first time and has a deployment version
    # set, then its ID will be used. This value may change over the lifetime of the workflow run,
    # but is deterministic and safe to use for branching. This is currently experimental.
    #
    # @return [WorkerDeploymentVersion, nil] the current deployment version if any.
    def self.current_deployment_version
      _current.current_deployment_version
    end

    # @return [Integer] Current number of events in history. This value is the current history event count up until the
    #   current task. Note, this value may not be up to date when accessed in a query.
    def self.current_history_length
      _current.current_history_length
    end

    # @return [Integer] Current history size in bytes. This value is the current history size up until the current task.
    #   Note, this value may not be up to date when accessed in a query.
    def self.current_history_size
      _current.current_history_size
    end

    # @return [UpdateInfo] Current update info if this code is running inside an update. This is set via a Fiber-local
    #   storage so it is only visible to the current handler fiber.
    def self.current_update_info
      _current.current_update_info
    end

    # Mark a patch as deprecated.
    #
    # This marks a workflow that had {patched} in a previous version of the code as no longer applicable because all
    # workflows that use the old code path are done and will never be queried again. Therefore the old code path is
    # removed as well.
    #
    # @param patch_id [Symbol, String] Patch ID.
    def self.deprecate_patch(patch_id)
      _current.deprecate_patch(patch_id)
    end

    # Execute an activity and return its result. Either `start_to_close_timeout` or `schedule_to_close_timeout` _must_
    # be set. The `heartbeat_timeout` should be set for any non-immediately-completing activity so it can receive
    # cancellation. To run an activity in the background, use a {Future}.
    #
    # @note Using an already-canceled cancellation may give a different exception than canceling after started. Use
    #   {Error.canceled?} to check if the exception is a cancellation either way.
    #
    # @param activity [Class<Activity::Definition>, Symbol, String] Activity definition class or activity name.
    # @param args [Array<Object>] Arguments to the activity.
    # @param task_queue [String] Task queue to run the activity on. Defaults to the current workflow's task queue.
    # @param summary [String, nil] Single-line summary for this activity that may appear in CLI/UI. This can be in
    #   single-line Temporal markdown format. This is currently experimental.
    # @param schedule_to_close_timeout [Float, nil] Max amount of time the activity can take from first being scheduled
    #   to being completed before it times out. This is inclusive of all retries.
    # @param schedule_to_start_timeout [Float, nil] Max amount of time the activity can take to be started from first
    #   being scheduled.
    # @param start_to_close_timeout [Float, nil] Max amount of time a single activity run can take from when it starts
    #   to when it completes. This is per retry.
    # @param heartbeat_timeout [Float, nil] How frequently an activity must invoke heartbeat while running before it is
    #   considered timed out. This also affects how heartbeats are throttled, see general heartbeating documentation.
    # @param retry_policy [RetryPolicy] How an activity is retried on failure. If unset, a server-defined default is
    #   used. Set maximum attempts to 1 to disable retries.
    # @param cancellation [Cancellation] Cancellation to apply to the activity. How cancellation is treated is based on
    #   `cancellation_type`. This defaults to the workflow's cancellation, but may need to be overridden with a
    #   new/detached one if an activity is being run in an `ensure` after workflow cancellation.
    # @param cancellation_type [ActivityCancellationType] How the activity is treated when it is canceled from the
    #   workflow.
    # @param activity_id [String, nil] Optional unique identifier for the activity. This is an advanced setting that
    #   should not be set unless users are sure they need to. Contact Temporal before setting this value.
    # @param disable_eager_execution [Boolean] Whether eager execution is disabled. Eager activity execution is an
    #   optimization on some servers that sends activities back to the same worker as the calling workflow if they can
    #   run there. If `false` (the default), eager execution may still be disabled at the worker level or may not be
    #   requested due to lack of available slots.
    # @param priority [Priority] Priority of the activity. This is currently experimental.
    # @param arg_hints [Array<Object>, nil] Overrides converter hints for arguments if any. If unset/nil and the
    #   activity definition has arg hints, those are used by default.
    # @param result_hint [Object, nil] Overrides converter hint for result if any. If unset/nil and the activity
    #   definition has result hint, it is used by default.
    #
    # @return [Object] Result of the activity.
    # @raise [Error::ActivityError] Activity failed (and retry was disabled or exhausted).
    # @raise [Error::CanceledError] Activity was canceled before started. When canceled after started (and not
    #   waited-then-swallowed), instead this canceled error is the cause of a {Error::ActivityError}.
    def self.execute_activity(
      activity,
      *args,
      task_queue: info.task_queue,
      summary: nil,
      schedule_to_close_timeout: nil,
      schedule_to_start_timeout: nil,
      start_to_close_timeout: nil,
      heartbeat_timeout: nil,
      retry_policy: nil,
      cancellation: Workflow.cancellation,
      cancellation_type: ActivityCancellationType::TRY_CANCEL,
      activity_id: nil,
      disable_eager_execution: false,
      priority: Priority.default,
      arg_hints: nil,
      result_hint: nil
    )
      _current.execute_activity(
        activity, *args,
        task_queue:, summary:, schedule_to_close_timeout:, schedule_to_start_timeout:, start_to_close_timeout:,
        heartbeat_timeout:, retry_policy:, cancellation:, cancellation_type:, activity_id:, disable_eager_execution:,
        priority:, arg_hints:, result_hint:
      )
    end

    # Shortcut for {start_child_workflow} + {ChildWorkflowHandle.result}. See those two calls for more details.
    def self.execute_child_workflow(
      workflow,
      *args,
      id: random.uuid,
      task_queue: info.task_queue,
      static_summary: nil,
      static_details: nil,
      cancellation: Workflow.cancellation,
      cancellation_type: ChildWorkflowCancellationType::WAIT_CANCELLATION_COMPLETED,
      parent_close_policy: ParentClosePolicy::TERMINATE,
      execution_timeout: nil,
      run_timeout: nil,
      task_timeout: nil,
      id_reuse_policy: WorkflowIDReusePolicy::ALLOW_DUPLICATE,
      retry_policy: nil,
      cron_schedule: nil,
      memo: nil,
      search_attributes: nil,
      priority: Priority.default,
      arg_hints: nil,
      result_hint: nil
    )
      start_child_workflow(
        workflow, *args,
        id:, task_queue:, static_summary:, static_details:, cancellation:, cancellation_type:,
        parent_close_policy:, execution_timeout:, run_timeout:, task_timeout:, id_reuse_policy:,
        retry_policy:, cron_schedule:, memo:, search_attributes:, priority:, arg_hints:, result_hint:
      ).result
    end

    # Execute an activity locally in this same workflow task and return its result. This should usually only be used for
    # short/simple activities where the result performance matters. Either `start_to_close_timeout` or
    # `schedule_to_close_timeout` _must_ be set. To run an activity in the background, use a {Future}.
    #
    # @note Using an already-canceled cancellation may give a different exception than canceling after started. Use
    #   {Error.canceled?} to check if the exception is a cancellation either way.
    #
    # @param activity [Class<Activity::Definition>, Symbol, String] Activity definition class or name.
    # @param args [Array<Object>] Arguments to the activity.
    # @param schedule_to_close_timeout [Float, nil] Max amount of time the activity can take from first being scheduled
    #   to being completed before it times out. This is inclusive of all retries.
    # @param schedule_to_start_timeout [Float, nil] Max amount of time the activity can take to be started from first
    #   being scheduled.
    # @param start_to_close_timeout [Float, nil] Max amount of time a single activity run can take from when it starts
    #   to when it completes. This is per retry.
    # @param retry_policy [RetryPolicy] How an activity is retried on failure. If unset, a server-defined default is
    #   used. Set maximum attempts to 1 to disable retries.
    # @param local_retry_threshold [Float, nil] If the activity is retrying and backoff would exceed this value, a timer
    #   is scheduled and the activity is retried after. Otherwise, backoff will happen internally within the task.
    #   Defaults to 1 minute.
    # @param cancellation [Cancellation] Cancellation to apply to the activity. How cancellation is treated is based on
    #   `cancellation_type`. This defaults to the workflow's cancellation, but may need to be overridden with a
    #   new/detached one if an activity is being run in an `ensure` after workflow cancellation.
    # @param cancellation_type [ActivityCancellationType] How the activity is treated when it is canceled from the
    #   workflow.
    # @param activity_id [String, nil] Optional unique identifier for the activity. This is an advanced setting that
    #   should not be set unless users are sure they need to. Contact Temporal before setting this value.
    # @param arg_hints [Array<Object>, nil] Overrides converter hints for arguments if any. If unset/nil and the
    #   activity definition has arg hints, those are used by default.
    # @param result_hint [Object, nil] Overrides converter hint for result if any. If unset/nil and the activity
    #   definition has result hint, it is used by default.
    #
    # @return [Object] Result of the activity.
    # @raise [Error::ActivityError] Activity failed (and retry was disabled or exhausted).
    # @raise [Error::CanceledError] Activity was canceled before started. When canceled after started (and not
    #   waited-then-swallowed), instead this canceled error is the cause of a {Error::ActivityError}.
    def self.execute_local_activity(
      activity,
      *args,
      schedule_to_close_timeout: nil,
      schedule_to_start_timeout: nil,
      start_to_close_timeout: nil,
      retry_policy: nil,
      local_retry_threshold: nil,
      cancellation: Workflow.cancellation,
      cancellation_type: ActivityCancellationType::TRY_CANCEL,
      activity_id: nil,
      arg_hints: nil,
      result_hint: nil
    )
      _current.execute_local_activity(
        activity, *args,
        schedule_to_close_timeout:, schedule_to_start_timeout:, start_to_close_timeout:,
        retry_policy:, local_retry_threshold:, cancellation:, cancellation_type:,
        activity_id:, arg_hints:, result_hint:
      )
    end

    # Get a handle to an external workflow for canceling and issuing signals.
    #
    # @param workflow_id [String] Workflow ID.
    # @param run_id [String, nil] Optional, specific run ID.
    #
    # @return [ExternalWorkflowHandle] External workflow handle.
    def self.external_workflow_handle(workflow_id, run_id: nil)
      _current.external_workflow_handle(workflow_id, run_id:)
    end

    # @return [Boolean] Whether the current code is executing in a workflow.
    def self.in_workflow?
      _current_or_nil != nil
    end

    # @return [Info] Information about the current workflow.
    def self.info
      _current.info
    end

    # @return [Definition, nil] Workflow class instance. This should always be present except in
    #   {Worker::Interceptor::Workflow::Inbound.init} where it will be nil.
    def self.instance
      _current.instance
    end

    # @return [Logger] Logger for the workflow. This is a scoped logger that automatically appends workflow details to
    #   every log and takes care not to log during replay.
    def self.logger
      _current.logger
    end

    # @return [Hash{String, Symbol => Object}] Memo for the workflow. This is a read-only view of the memo. To update
    #   the memo, use {upsert_memo}. This always returns the same instance and updates are reflected on the returned
    #   instance, so it is not technically frozen.
    def self.memo
      _current.memo
    end

    # @return [Metric::Meter] Metric meter to create metrics on. This metric meter already contains some
    #   workflow-specific attributes and takes care not to apply metrics during replay.
    def self.metric_meter
      _current.metric_meter
    end

    # @return [Time] Current UTC time for this workflow. This creates and returns a new {::Time} instance every time it
    #   is invoked, it is not the same instance continually mutated.
    def self.now
      _current.now
    end

    # Patch a workflow.
    #
    # When called, this will only return true if code should take the newer path which means this is either not
    # replaying or is replaying and has seen this patch before. Results for successive calls to this function for the
    # same ID and workflow are memoized. Use {deprecate_patch} when all workflows are done and will never be queried
    # again. The old code path can be removed at that time too.
    #
    # @param patch_id [Symbol, String] Patch ID.
    # @return [Boolean] True if this should take the newer patch, false if it should take the old path.
    def self.patched(patch_id)
      _current.patched(patch_id)
    end

    # @return [Converters::PayloadConverter] Payload converter for the workflow.
    def self.payload_converter
      _current.payload_converter
    end

    # @return [Hash<String, Definition::Query>] Query handlers for this workflow. This hash is mostly immutable except
    #   for `[]=` (and `store`) which can be used to set a new handler, or can be set with `nil` to remove a handler.
    #   For most use cases, defining a handler as a `workflow_query` method is best.
    def self.query_handlers
      _current.query_handlers
    end

    # @return [Random] Deterministic instance of {::Random} for use in a workflow. This instance should be accessed each
    #   time needed, not stored. This instance may be recreated with a different seed in special cases (e.g. workflow
    #   reset). Do not use any other randomization inside workflow code.
    def self.random
      _current.random
    end

    # @return [SearchAttributes] Search attributes for the workflow. This is a read-only view of the attributes. To
    #   update the attributes, use {upsert_search_attributes}. This always returns the same instance and updates are
    #   reflected on the returned instance, so it is not technically frozen.
    def self.search_attributes
      _current.search_attributes
    end

    # @return [Hash<String, Definition::Signal>] Signal handlers for this workflow. This hash is mostly immutable except
    #   for `[]=` (and `store`) which can be used to set a new handler, or can be set with `nil` to remove a handler.
    #   For most use cases, defining a handler as a `workflow_signal` method is best.
    def self.signal_handlers
      _current.signal_handlers
    end

    # Sleep in a workflow for the given time.
    #
    # @param duration [Float, nil] Time to sleep in seconds. `nil` represents infinite, which does not start a timer and
    #   just waits for cancellation. `0` is assumed to be 1 millisecond and still results in a server-side timer. This
    #   value cannot be negative. Since Temporal timers are server-side, timer resolution may not end up as precise as
    #   system timers.
    # @param summary [String, nil] A simple string identifying this timer that may be visible in UI/CLI. While it can be
    #   normal text, it is best to treat as a timer ID. This is currently experimental.
    # @param cancellation [Cancellation] Cancellation for this timer.
    # @raise [Error::CanceledError] Sleep canceled.
    def self.sleep(duration, summary: nil, cancellation: Workflow.cancellation)
      _current.sleep(duration, summary:, cancellation:)
    end

    # Start a child workflow and return the handle.
    #
    # @param workflow [Class<Workflow::Definition>, Symbol, String] Workflow definition class or workflow name.
    # @param args [Array<Object>] Arguments to the workflow.
    # @param id [String] Unique identifier for the workflow execution. Defaults to a new UUID from {random}.
    # @param task_queue [String] Task queue to run the workflow on. Defaults to the current workflow's task queue.
    # @param static_summary [String, nil] Fixed single-line summary for this workflow execution that may appear in
    #   CLI/UI. This can be in single-line Temporal markdown format. This is currently experimental.
    # @param static_details [String, nil] Fixed details for this workflow execution that may appear in CLI/UI. This can
    #   be in Temporal markdown format and can be multiple lines. This is a fixed value on the workflow that cannot be
    #   updated. For details that can be updated, use {Workflow.current_details=} within the workflow. This is currently
    #   experimental.
    # @param cancellation [Cancellation] Cancellation to apply to the child workflow. How cancellation is treated is
    #   based on `cancellation_type`. This defaults to the workflow's cancellation.
    # @param cancellation_type [ChildWorkflowCancellationType] How the child workflow will react to cancellation.
    # @param parent_close_policy [ParentClosePolicy] How to handle the child workflow when the parent workflow closes.
    # @param execution_timeout [Float, nil] Total workflow execution timeout in seconds including retries and continue
    #   as new.
    # @param run_timeout [Float, nil] Timeout of a single workflow run inseconds.
    # @param task_timeout [Float, nil] Timeout of a single workflow task in seconds.
    # @param id_reuse_policy [WorkflowIDReusePolicy] How already-existing IDs are treated.
    # @param retry_policy [RetryPolicy, nil] Retry policy for the workflow.
    # @param cron_schedule [String, nil] Cron schedule. Users should use schedules instead of this.
    # @param memo [Hash{String, Symbol => Object}, nil] Memo for the workflow.
    # @param search_attributes [SearchAttributes, nil] Search attributes for the workflow.
    # @param priority [Priority] Priority of the workflow. This is currently experimental.
    # @param arg_hints [Array<Object>, nil] Overrides converter hints for arguments if any. If unset/nil and the
    #   workflow definition has arg hints, those are used by default.
    # @param result_hint [Object, nil] Overrides converter hint for result if any. If unset/nil and the workflow
    #   definition has result hint, it is used by default.
    #
    # @return [ChildWorkflowHandle] Workflow handle to the started workflow.
    # @raise [Error::WorkflowAlreadyStartedError] Workflow already exists for the ID.
    # @raise [Error::CanceledError] Starting of the child was canceled.
    def self.start_child_workflow(
      workflow,
      *args,
      id: random.uuid,
      task_queue: info.task_queue,
      static_summary: nil,
      static_details: nil,
      cancellation: Workflow.cancellation,
      cancellation_type: ChildWorkflowCancellationType::WAIT_CANCELLATION_COMPLETED,
      parent_close_policy: ParentClosePolicy::TERMINATE,
      execution_timeout: nil,
      run_timeout: nil,
      task_timeout: nil,
      id_reuse_policy: WorkflowIDReusePolicy::ALLOW_DUPLICATE,
      retry_policy: nil,
      cron_schedule: nil,
      memo: nil,
      search_attributes: nil,
      priority: Priority.default,
      arg_hints: nil,
      result_hint: nil
    )
      _current.start_child_workflow(
        workflow, *args,
        id:, task_queue:, static_summary:, static_details:, cancellation:, cancellation_type:,
        parent_close_policy:, execution_timeout:, run_timeout:, task_timeout:, id_reuse_policy:,
        retry_policy:, cron_schedule:, memo:, search_attributes:, priority:, arg_hints:, result_hint:
      )
    end

    # @return [Hash<Object, Object>] General in-workflow storage. Most users will store state on the workflow class
    #   instance instead, this is only for utilities without access to the class instance.
    def self.storage
      _current.storage
    end

    # Run the block until the timeout is reached. This is backed by {sleep}. This does not accept cancellation because
    # it is expected the block within will properly handle/bubble cancellation.
    #
    # @param duration [Float, nil] Duration for the timeout. This is backed by {sleep} so see that method for details.
    # @param exception_class [Class<Exception>] Exception to raise on timeout. Defaults to {::Timeout::Error} like
    #   {::Timeout.timeout}. Note that {::Timeout::Error} is considered a workflow failure exception, not a task failure
    #   exception.
    # @param message [String] Message to use for timeout exception. Defaults to "execution expired" like
    #   {::Timeout.timeout}.
    # @param summary [String] Timer summary for the timer created by this timeout. This is backed by {sleep} so see that
    #   method for details. This is currently experimental.
    #
    # @yield Block to run with a timeout.
    # @return [Object] The result of the block.
    # @raise [Exception] Upon timeout, raises whichever class is set in `exception_class` with the message of `message`.
    def self.timeout(
      duration,
      exception_class = Timeout::Error,
      message = 'execution expired',
      summary: 'Timeout timer',
      &
    )
      _current.timeout(duration, exception_class, message, summary:, &)
    end

    # @return [Hash<String, Definition::Update>] Update handlers for this workflow. This hash is mostly immutable except
    #   for `[]=` (and `store`) which can be used to set a new handler, or can be set with `nil` to remove a handler.
    #   For most use cases, defining a handler as a `workflow_update` method is best.
    def self.update_handlers
      _current.update_handlers
    end

    # Issue updates to the workflow memo.
    #
    # @param hash [Hash{String, Symbol => Object, nil}] Updates to apply. Value can be `nil` to effectively remove the
    #   memo value.
    def self.upsert_memo(hash)
      _current.upsert_memo(hash)
    end

    # Issue updates to the workflow search attributes.
    #
    # @param updates [Array<SearchAttributes::Update>] Updates to apply. Note these are {SearchAttributes::Update}
    #   objects which are created via {SearchAttributes::Key.value_set} and {SearchAttributes::Key.value_unset} methods.
    def self.upsert_search_attributes(*updates)
      _current.upsert_search_attributes(*updates)
    end

    # Wait for the given block to return a "truthy" value (i.e. any value other than `false` or `nil`). The block must
    # be side-effect free since it may be invoked frequently during event loop iteration. To timeout a wait, {timeout}
    # can be used. This cannot be used in side-effect-free contexts such as `initialize`, queries, or update validators.
    #
    # This is very commonly used to wait on a value to be set by a handler, e.g.
    # `Temporalio::Workflow.wait_condition { @some_value }`. Special care was taken to only wake up a single wait
    # condition when it evaluates to true. Therefore if multiple wait conditions are waiting on the same thing, only one
    # is awoken at a time, which means the code immediately following that wait condition can change the variable before
    # other wait conditions are evaluated. This is a useful property for building mutexes/semaphores.
    #
    # @param cancellation [Cancellation, nil] Cancellation to cancel the wait. This defaults to the workflow's
    #   cancellation.
    # @yield Block that is run many times to test for truthiness.
    # @yieldreturn [Object] Value to check whether truthy or falsy.
    #
    # @return [Object] Truthy value returned from the block.
    # @raise [Error::CanceledError] Wait was canceled.
    def self.wait_condition(cancellation: Workflow.cancellation, &)
      raise 'Block required' unless block_given?

      _current.wait_condition(cancellation:, &)
    end

    # @!visibility private
    def self._current
      current = _current_or_nil
      raise Error, 'Not in workflow environment' if current.nil?

      current
    end

    # @!visibility private
    def self._current_or_nil
      # We choose to use Fiber.scheduler instead of Fiber.current_scheduler here because the constructor of the class is
      # not scheduled on this scheduler and so current_scheduler is nil during class construction.
      sched = Fiber.scheduler
      return sched.context if sched.is_a?(Internal::Worker::WorkflowInstance::Scheduler)

      nil
    end

    # Unsafe module contains only-in-workflow methods that are considered unsafe. These should not be used unless the
    # consequences are understood.
    module Unsafe
      # @return [Boolean] True if the workflow is replaying, false otherwise. Most code should not check this value.
      def self.replaying?
        Workflow._current.replaying?
      end

      # Run a block of code with illegal call tracing disabled. Users should be cautious about using this as it can
      # often signify unsafe code.
      #
      # @yield Block to run with call tracing disabled
      #
      # @return [Object] Result of the block.
      def self.illegal_call_tracing_disabled(&)
        Workflow._current.illegal_call_tracing_disabled(&)
      end

      # Run a block of code with IO enabled. Specifically this allows the `io_wait` call of the fiber scheduler to work.
      # Users should be cautious about using this as it can often signify unsafe code. Note, this is often only
      # applicable to network code as file IO and most process-based IO does not go through scheduler `io_wait`.
      def self.io_enabled(&)
        Workflow._current.io_enabled(&)
      end

      # Run a block of code with the durable/deterministic workflow Fiber scheduler off. This means fallback to default
      # fiber scheduler and no workflow helpers will be available in the block. This is usually only needed in advanced
      # situations where a third party library does something like use "Timeout" in a way that shouldn't be made
      # durable.
      def self.durable_scheduler_disabled(&)
        Workflow._current.durable_scheduler_disabled(&)
      end
    end

    # Error that is raised by a workflow out of the primary workflow method to issue a continue-as-new.
    class ContinueAsNewError < Error
      attr_accessor :args, :workflow, :task_queue, :run_timeout, :task_timeout,
                    :retry_policy, :memo, :search_attributes, :arg_hints, :headers

      # Create a continue as new error.
      #
      # @param args [Array<Object>] Arguments for the new workflow.
      # @param workflow [Class<Workflow::Definition>, String, Symbol, nil] Workflow definition class or workflow name.
      #   If unset/nil, the current workflow is used.
      # @param task_queue [String, nil] Task queue for the workflow. If unset/nil, the current workflow task queue is
      #   used.
      # @param run_timeout [Float, nil] Timeout of a single workflow run in seconds. The default is _not_ carried over
      #   from the current workflow.
      # @param task_timeout [Float, nil] Timeout of a single workflow task in seconds. The default is _not_ carried over
      #   from the current workflow.
      # @param retry_policy [RetryPolicy, nil] Retry policy for the workflow. If unset/nil, the current workflow retry
      #   policy is used.
      # @param memo [Hash{String, Symbol => Object}, nil] Memo for the workflow. If unset/nil, the current workflow memo
      #   is used.
      # @param search_attributes [SearchAttributes, nil] Search attributes for the workflow. If unset/nil, the current
      #   workflow search attributes are used.
      # @param arg_hints [Array<Object>, nil] Overrides converter hints for arguments if any. If unset/nil and the
      #   workflow definition has arg hints, those are used by default.
      # @param headers [Hash<String, Object>] Headers for the workflow. The default is _not_ carried over from the
      #   current workflow.
      def initialize(
        *args,
        workflow: nil,
        task_queue: nil,
        run_timeout: nil,
        task_timeout: nil,
        retry_policy: nil,
        memo: nil,
        search_attributes: nil,
        arg_hints: nil,
        headers: {}
      )
        super('Continue as new')
        @args = args
        @workflow = workflow
        @task_queue = task_queue
        @run_timeout = run_timeout
        @task_timeout = task_timeout
        @retry_policy = retry_policy
        @memo = memo
        @search_attributes = search_attributes
        @arg_hints = arg_hints
        @headers = headers
        Workflow._current.initialize_continue_as_new_error(self)
      end
    end

    # Error raised when a workflow does something with a side effect in an improper context. In `initialize`, query
    # handlers, and update validators, a workflow cannot do anything that would generate a command (e.g. starting an
    # activity) or anything that could wait (e.g. scheduling a fiber, running a future, or using a wait condition).
    class InvalidWorkflowStateError < Error; end

    # Error raised when a workflow does something potentially non-deterministic such as making an illegal call. Note,
    # non-deterministic errors during replay do not raise an error that can be caught, those happen internally. But this
    # error can still be used with configuring workflow failure exception types to change non-deterministic errors from
    # task failures to workflow failures.
    class NondeterminismError < Error; end
  end
end
