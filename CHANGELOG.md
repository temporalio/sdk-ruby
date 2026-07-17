<!--
High-level release notes.
Loosely based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

When your PR includes a user-facing change, add an entry below under the
appropriate heading (create the heading if it does not yet exist). Within
each heading content can be free-form. Feel free to include examples, links
to docs, or any other relevant information.

### Added            — new features
### Changed          — changes in existing functionality
### Deprecated       — soon-to-be-removed features
### Breaking Changes — removed or backwards-incompatible features
### Fixed            — notable bug fixes
### Security         — notable security fixes
-->

# Changelog

## [Unreleased]

### Breaking Changes

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

### Breaking Changes

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

See https://docs.temporal.io/standalone-activity for the cross-SDK feature overview.

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
