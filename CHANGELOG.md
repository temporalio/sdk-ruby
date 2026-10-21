# Changelog

## [1.10.0] - 2026-10-19

### Added

- Added experimental `versioning_override:` to `Workflow.start_child_workflow` and `Workflow.execute_child_workflow`, including `VersioningOverride::OneTime`, to route children independently of their parent on Temporal Server 1.32.0 or later. Rejected overrides raise `Error::ChildWorkflowError` with an `Error::InvalidVersioningOverrideError` cause.
- Core: The OTLP metrics exporter can export histograms as OpenTelemetry exponential histograms, which Prometheus-compatible backends store as native histograms, when an SDK enables the option, including through the C bridge. It applies to every histogram, including custom ones, and names each series with a suffix, `_native` by default, so it never shares a name with the fixed-bucket series it replaces. It cannot be combined with histogram bucket overrides. Explicit buckets remain the default.
- Core: The `temporal_activity_execution_failed` and `temporal_local_activity_execution_failed` worker metrics now carry a `failure_reason` attribute. Each is now split into one time series per reason, which may affect existing dashboards.
- Core: External workflow signal and cancellation resolution activations now include the typed server failure cause alongside the existing failure.
- Core: Workflow completion-as-cancelled commands can now carry details for recording on the terminal history event.
- Core: Workflow task completions larger than the gRPC request size limit are now paginated automatically when the namespace supports it. Paginated workflow task completions require Temporal Server 1.32.0 or later.

### Stabilized

- Priority is no longer marked as experimental.
- The `dev_server_` and `test_server_` options of `Testing::WorkflowEnvironment.start_local` and `start_time_skipping` are no longer described as unstable.

### :boom: Breaking Changes

- `Schedule::Policy#catchup_window` now defaults to `nil`. If unspecified the server configured default is used.
- Core: Replay detects changes to the service or operation of scheduled Nexus operations, reporting nondeterminism while retaining compatibility with histories recorded before these checks.

### Fixed

- The test `ActivityEnvironment` no longer adds `detail_hints` to the details it passes to `on_heartbeat`.
- Require `json < 3` to prevent JSON payload decoding failures with JSON 3.
- Core: Workers now replay workflows paused before a scheduled task starts, allowing those workflows to make progress after unpause.
- Core: Task-poll targets no longer decrease after cancelled or timed-out polls. Affected pollers still retain their slot during backoff, while resource-exhaustion errors still reduce the target.
- Core: Replay now preserves which local activity results were delivered together for newly recorded histories. This prevents local activity scheduling which was conditional on local activity resolution order from assigning recorded results to different handles. Older markers keep their existing behavior.
- Core: Workflow poll balancing now lets non-sticky pollers use capacity after sticky pollers reach their configured or autoscaled polling limit.
- Core: Every path that fails a workflow task now only reports the failure to server on the task's first attempt, and later attempts are left to time out. Previously `PayloadsTooLarge` failures and history fetch failures were re-reported on every attempt.
- Core: The `workflow_task_execution_failed` metric is now recorded for every failed workflow task attempt, including attempts whose failure was not sent to the server, and its `failure_reason` tag distinguishes `GrpcMessageTooLarge`, `PayloadsTooLarge`, and `RequestTooLarge` on every path.
- Core: Worker shutdown now drains activity completions that are still flushing their result to the server before finishing. Previously such a completion — typically one whose final heartbeat RPC was still in flight — could be permanently stranded by shutdown: the activity's result was never reported (the server had to time the attempt out before retrying it), and workers missed shutdown's slot-permit release deadline, panicking in debug builds.
- Core: The Prometheus exporter now appends `_total` to counter metric names when an SDK enables the counter suffix option.
- Core: Update-with-start `ExecuteMultiOperation` calls now use Core's long-poll timeout instead of the normal RPC timeout, avoiding premature failures while waiting for an update to reach its requested stage.
- Core: An activity failure caused by oversized final heartbeat details is now counted in the `temporal_activity_execution_failed` metric as `failure_reason="PayloadsTooLarge"`. Previously it was counted under the reason for the failure the activity itself reported, and was not counted at all when that failure was benign, even though a payload-limit failure was reported instead.
- Core: Workers now warn when autoscaling task polling encounters errors continuously for one minute. Repeated warnings use exponential backoff up to 15-minute intervals and stop after polling recovers.
- Core: Workers no longer send worker heartbeats or appear in centralized heartbeat reports before they begin polling.
- Core: Nexus tasks are now timed out locally even when the server sends a `request-timeout` header that falls outside the Nexus duration grammar, such as a negative value for a task whose deadline has already elapsed, a sub-millisecond unit, or a multi-unit value like `1m30s`. Previously such a header was ignored entirely, so the handler was never told the task had timed out, and a task left unanswered could block worker shutdown indefinitely.
- Core: Workers with a small workflow cache no longer briefly stop accepting new workflows. Sticky workflow-task pollers could consume every workflow-cache permit and starve the non-sticky poller, so the worker would stop picking up new workflows until a poll timed out (up to ~60s). The poll balancer now reserves a non-sticky slot against the workflow cache size rather than the slot supplier size.
- Core: Worker heartbeats now report correct task-slot and poller counts when using buffered or custom metrics backends, including the Python SDK's `MetricBuffer`. Previously these counts could remain `0` because heartbeat accounting depended on reading labels from backend-owned attributes.
- Core: Local activities still running when their workflow is evicted or the worker shuts down now always receive a cancellation. Local activities no longer retry ordinary failures or start-to-close timeouts after cancellation has been requested, matching non-local activities. Workflow code no longer observes a spurious local activity cancellation when its run is evicted or completes while the local activity is backing off between retries.
- Core: Workers no longer panic when evicting a workflow with buffered local activity results. Completed activations' output is recorded before eviction, without recording eviction-induced cancellations.
- Core: A workflow task that arrives while a workflow waits on a local activity, such as a legacy query, now waits until the current workflow task is reported. Previously it replaced that workflow task ("Trying to send a new WFT for a run which already has one!"), which then timed out on the server and could leave the workflow stuck on a nondeterminism error.

### Security

- Core: Ephemeral server downloads now use `zip` 9.0 for ZIP extraction, replacing the 8.x dependency [yanked upstream for security issues](https://github.com/zip-rs/zip2/issues/1075#issuecomment-6209381974).

## [v1.9.0] - 2026-09-14

### Changed

- Standalone Activities are now generally available (GA). (Standalone Activities as Nexus operations
  and Standalone Activities operator commands remain experimental. Operator commands are `pause`,
  `unpause`, `updateOptions`, `restoreOriginal`.)

### :boom: Breaking Changes

- Duplicate keys in `update_options` are now an error.
- Renamed the standalone activity `static_summary:` option on `Client#start_activity` and
  `Client#execute_activity` to `summary:`, and `Client::ActivityExecution::Description#static_summary`
  to `#summary`.

## [v1.8.0] - 2026-09-10

### Added

#### Standalone Activity operator commands

- `Client::ActivityHandle` now supports operator commands for standalone activities: `#pause`,
  `#unpause` and `#update_options`.
- Added opt-in payload fields to `Client::ActivityHandle#describe`: `include_input:`,
  `include_outcome:`, `include_heartbeat_details:` and `include_last_failure:`, all default
  `false`.
- Add missing description fields: `execution_time`, `start_delay`, `total_heartbeat_count`.

### :boom: Breaking Changes

- `Description` payload fields are now opt-in: `input`, `outcome`, `heartbeat_details`, `last_failure`.

### Fixed

- Canceling a fiber-executor activity no longer wedges the worker if using a `Fiber#transfer` based scheduler
  (such as `async`). The exception is now delivered through the scheduler's `fiber_interrupt` hook when it
  provides one.

## [v1.7.0] - 2026-08-20

### Added

- Added `Temporalio::Runtime::LoggingOptions#log_format` to select compact, pretty, or
  newline-delimited JSON output for Core logs written to the console.
- Added `FailureConverter` `process_common_attributes:` to customize the value sent to the payload converter when
  encoding common failure attributes.

- Added the `Temporalio::Worker` `max_eager_activity_reservations_per_workflow_task:` option to
  configure the number of activity slots reserved for eager execution per workflow task. Values
  must be positive; use `disable_eager_activity_execution: true` to disable eager execution.

### :boom: Breaking Changes

- By default, workers now proactively validate outbound payload/memo sizes before sending: a field
  over the warn threshold is logged
  (`[TMPRL1103]` at `WARN`) but still sent, while a task completion over the error limit is failed
  retryably (`[TMPRL1103]` at `ERROR`) instead of sent. Previously these reached the server, which
  terminated the workflow or failed the activity non-retryably; failing retryably instead lets a
  corrected workflow or activity be redeployed and recover. Tune warn thresholds via
  `Temporalio::Client::Connection::PayloadLimitsOptions` (passed as the connection's
  `payload_limits:`). If you use a proxy between the worker and server that alters the size of
  payloads (e.g. compression, encryption, external storage), it is advised that you disable size
  enforcement by setting `disable_payload_error_limit: true` on the worker.

### Changed

- User metadata fields (static_summary, static_details, current_details, activity summary, timer
  summary) are no longer marked as experimental.

### Fixed

- `Temporalio::Client::WorkflowHandle#result` now preserves fiber-local `Thread.current[]` context
  while fetching workflow history, allowing gRPC interceptors to apply request-scoped RPC options.
- `Temporalio::Client::WorkflowHandle#result` no longer returns `nil` while a workflow is still
  running when a history long poll expires without returning an event.

### Added

- Worker heartbeats now report the SDK runtime and hosting/platform information the first time each
  worker heartbeats successfully. Set `Temporalio::Runtime.new(disable_environment_info: true)` to
  opt out of environment reporting entirely.

#### Core updates

- Bumped bundled sdk-core to 0.6.0.Bump sdk-core to 8cf682b7 (0.6.0). Changes in
  temporalio/ext/src/client.rs, envconfig.rs, worker.rs to use .builder().

## [v1.6.0] - 2026-07-16

### Added

- Exposed `Temporalio::Workflow::ContinueAsNewError#backoff_start_interval`, to allow the new workflow to start after a delay.
- Added the experimental `Temporalio::Worker` `patch_activation_callback:` option, allowing workers to decide whether a first non-replay `Temporalio::Workflow.patched` call should activate a patch during rolling deployments.

#### Experimental FIPS builds

The native extension can now be built with `TEMPORALIO_FIPS=1` to use the FIPS-mode
`aws-lc-rs` TLS backend for gRPC and OTLP metrics. This is opt-in, source-build only.
FIPS builds use SHA-256 rather than MD5 for the default worker build ID and warn when
the Ruby OpenSSL runtime is not itself in FIPS mode.

#### Experimental RBS and RBI signatures are included in the gem

Released gems now contain the SDK's maintained RBS signatures in `sig/` and Sorbet RBI
signatures in `rbi/`, including generated types for Temporal API messages and services.
These type signatures are subject to change in future releases as we move towards a stronger typing story.

### Changed

#### gRPC transport compression defaults to gzip

Client connections now use gzip transport compression by default. Pass
`grpc_compression: Temporalio::Client::Connection::GrpcCompressionOptions::None.new` to
`Client.connect` or `Client::Connection.new` to opt out.

### Fixed

#### `Workflow.suggest_continue_as_new_reasons` returns workflow enum values

Workflow activations containing continue-as-new suggestion reasons previously failed because the
worker tried to call `to_i` on bridge enum symbols. Continue-as-new suggestion reasons are now
converted from bridge enum symbols to `Temporalio::SuggestContinueAsNewReason` integer enum values before being exposed to workflows.

#### Deadlock errors from workflow futures fail the current workflow task

A workflow deadlock raised inside `Temporalio::Workflow::Future` is no longer deferred until the
future is awaited. The worker fails the current workflow task immediately, preventing commands
created before the deadlock from being recorded as a successful partial command batch.

#### Scheduler waits for the Protobuf object-cache mutex

The workflow scheduler no longer yields while a workflow fiber is blocked on the
`google-protobuf` object-cache mutex. This prevents a workflow task from completing with only part
of a command batch when Protobuf serialization blocks.

#### `replay_workflow` shutdown after nondeterminism

Fixed a race in `replay_workflow` where if a NDE was hit, worker shutdown could panic if it happens before async activation completion completes.

#### Core updates

- Retried transport-originated gRPC `CANCELLED` errors, such as a connection closure or GOAWAY,
  using the normal RPC retry policy while continuing not to retry application-initiated
  cancellations.
- Resource sampling interval for worker heartbeating now matches heartbeat interval rather than every 100ms
- Activities with a heartbeat timeout shorter than their start-to-close timeout now still enforce
  the start-to-close timeout while heartbeats succeed.
- Local activity completion after workflow eviction no longer risks a Core panic or dispatching a
  stale local activity.
- Corrected the `worker_task_slots_used` gauge so it does not count a slot that is currently being
  released.
- OTLP metric export failures are now emitted through Core telemetry, making them visible through
  the SDK logger.

## [v1.5.0] - 2026-06-11

### :boom: Breaking Changes

#### `Activity::Info` workflow fields are now nullable

With the introduction of Standalone Activities (see below), an activity is no longer guaranteed to
have been scheduled by a workflow. `Activity::Info#workflow_id`, `#workflow_run_id`,
`#workflow_type`, and `#workflow_namespace` are now nullable — they return `nil` when the activity
was started via `Client#start_activity` rather than from a workflow. A new `Activity::Info#namespace`
accessor is always set (falling back to the client's namespace for standalone activities) and is
the recommended replacement for the deprecated `#workflow_namespace`.

Existing workflow-only code paths are unaffected at runtime. The recommended migration is to call
`Activity::Info#in_workflow?` and branch on the result.

### Added

#### Standalone Activities

Activities can now be started directly from a client, independently of any workflow. `Client#start_activity`
and `Client#execute_activity` schedule a standalone activity execution by ID and task queue, accepting the
same `Activity::Definition` classes (or by-name strings/symbols) used in workflow-scheduled activities.
`Client::ActivityHandle` provides `#result`, `#describe`, `#cancel`, and `#terminate`; `Client#list_activities`
and `Client#count_activities` provide visibility-backed queries; and `Client#async_activity_handle` now
accepts a standalone-form `ActivityIDReference` (constructed via `ActivityIDReference.for_standalone`) for
async completion.

See <https://docs.temporal.io/standalone-activity> for the cross-SDK feature overview.

### Fixed

#### `execute_update_with_start_workflow` no longer raises `RPCError NOT_FOUND` on validator rejection

When a `workflow_update_validator` rejected an update sent via
`Client#execute_update_with_start_workflow` (or `#start_update_with_start_workflow` with
`wait_for_stage: COMPLETED`), the client polled history for an outcome that was never written
and surfaced the failure as `Temporalio::Error::RPCError` with code `NOT_FOUND`. The caller now
correctly receives `Temporalio::Error::WorkflowUpdateFailedError`. (#454)

#### Start Delay for Standalone Activities

`Client#start_activity` and `Client#execute_activity` now accept a `start_delay:` kwarg. When set, the server creates the activity immediately,
but defers dispatch to a worker until the delay elapses. Retry attempts do not re-apply the delay.
`ScheduleToStart` and `ScheduleToClose` timeout clocks begin counting after the delay
elapses; `StartToClose` and `Heartbeat` are unaffected. Currently experimental.
