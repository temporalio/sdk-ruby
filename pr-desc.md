# Add operator commands for standalone activities

Adds pause, unpause, reset, and update-options to standalone activities, plus
the describe surface needed to observe their effects.

Standalone activities already supported start, result, describe, cancel, and
terminate. This adds the four operator commands the server exposes for them, so
an operator can hold, resume, restart, and retune a running activity without
going through a workflow.

## API

On `Temporalio::Client::ActivityHandle`:

```ruby
handle.pause(reason = nil)
handle.unpause(reason: nil, jitter: nil)
handle.reset(keep_paused: false, jitter: nil,
             restore_original_options: false, reset_heartbeat: false)
handle.update_options(task_queue: ..., schedule_to_close_timeout: ...,
                      schedule_to_start_timeout: ..., start_to_close_timeout: ...,
                      heartbeat_timeout: ..., retry_policy: ..., priority: ...,
                      start_delay: ..., restore_original: false)
```

`update_options` uses an `UNSET` sentinel so a field mask is derived from
exactly the options you pass — passing `nil` explicitly clears a field, and
omitting it leaves the field untouched. It raises `ArgumentError` if
`restore_original` is combined with any other option, or if nothing is passed.
It returns the server's post-update view as a new top-level
`Temporalio::Client::ActivityExecutionOptions`.

`Temporalio::Client::ActivityExecutionStatus::PAUSED` is added (api#834). Note
that a *running* activity pauses to `PAUSE_REQUESTED` and only reaches `PAUSED`
once the worker drops the attempt; an activity paused while still scheduled
(via `start_delay`) goes straight to `PAUSED`.

## Describe: payload fields are opt-in

`DescribeActivityExecutionRequest` gates four payload-bearing fields behind
per-call flags (api#792). All four are now plumbed through `describe` and
**default to false**, matching Rust's `ActivityDescribeOptions`:

```ruby
handle.describe(include_input: true, include_outcome: true,
                include_heartbeat_details: true, include_last_failure: true)
```

This is a behavior change: `describe` previously hard-coded
`include_heartbeat_details` and `include_last_failure` to true. Callers that
read heartbeat details or the last failure must now ask for them. The rationale
is the one the proto gives — these fields carry arbitrarily large payloads and
shouldn't be fetched unless needed.

`ActivityExecution::Description` gained, alongside the existing
`heartbeat_details`:

- `has_input?` / `input(hints: nil)` — the full argument array
- `has_result?` / `result(result_hint: nil)` / `failure`
- `has_last_failure?` and `start_delay`, plus `execution_time` on
  `ActivityExecution`

The outcome is a result-or-failure oneof; it's flattened into `has_result?` /
`result` / `failure` rather than exposed as an outcome object, and none of them
raise — reading a description never raises the way `handle.result` does.
`failure` is the terminal outcome; `last_failure` remains the most recent
attempt's failure and may be set while the activity is still retrying.

## Interceptors

`Temporalio::Client::Interceptor::Outbound` gains `pause_activity`,
`unpause_activity`, `reset_activity`, and `update_activity_options` with
matching `*Input` data classes, and `DescribeActivityInput` carries the four
describe flags.

## Tests

- `client_activity_operator_commands_test.rb` — functional coverage of each
  command against a real server, each asserting an observable server-side state
  change rather than just a successful RPC. Includes update-options on a paused
  activity, describe reporting `PAUSED` for an activity paused while scheduled,
  the heartbeat-preservation behavior of each command, a test that describe's
  payload fields really are off by default, and both arms of the outcome oneof.
- `client_activity_operator_commands_interceptor_test.rb` — interceptor
  pass-through.
- `client_activity_operator_commands_build_test.rb` — request-building.

RBS signatures and Sorbet RBI files are updated alongside; steep and RuboCop are
clean.

## Notes for reviewers

- `has_input?` / `has_result?` / `has_last_failure?` use the `has_` prefix,
  which needs a `Naming/PredicatePrefix` suppression and differs from the SDK's
  26 other predicates (`connected?`, `standalone?`). They match
  `has_heartbeat_details?` in the same class — the SDK's only other `has_`
  predicate — and mirror the protobuf presence checks they wrap. Happy to rename
  to `input?` / `result?` / `last_failure?` if the SDK-wide style should win.
- `failure` has no direct precedent as an accessor name; it pairs with the
  existing `last_failure` the way the other SDKs pair a terminal-outcome failure
  with a last-attempt failure.
- `retry_state` on the outcome (api#843, server-populated since temporal#11321)
  is reachable via `raw_description` but has no typed accessor yet.

## Upstream dependencies

Requires a server with the standalone-activity operator-command APIs enabled
(`frontend.activityAPIsEnabled`). Relevant API changes already merged and
reflected here: api#792 (describe opt-ins), api#834 (`PAUSED` status), api#844
(request IDs), api#846 (removed `reset_attempts`/`reset_heartbeat` from
Unpause), api#848 (`reset_heartbeat` back on Reset, paired with
temporal#11417), api#807 (`execution_time`), api#804 / temporal#10745
(`start_delay` on update-options).
