# Changelog

## [Unreleased]

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