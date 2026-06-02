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