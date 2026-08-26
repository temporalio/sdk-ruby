# Ruby changes made by analogy to the Java review

Counterparts to Maciej's review of temporalio/sdk-java#3013, applied to the Ruby
SAA operator-commands branch (`gmt/operator-commands`). Four changes, each
mirroring a Java review comment. Currently **uncommitted**.

## The four changes

### 1. `Description#failure` → `#outcome_failure` — mirrors Comment F

> I'd rename this method to `getOutcomeFailure` or something to better
> differentiate it from `getLastFailure`. We should also change return type of
> both this and `getLastFailure` to `RuntimeException`.

One-line rename in `activity_execution.rb`, plus the RBS and RBI signatures.
Same rationale as Java: it is the terminal outcome, and `last_failure` sits
right next to it on the same class, so the bare name was ambiguous.

Ruby has no return-type half to mirror — Java also widened both getters to
`RuntimeException`, which has no analogue here.

### 2. `restore_original:` kwarg → `restore_original_options` method — mirrors Comment H

> Consider alternative design: `UpdateActivityOptions` does not have
> `restoreOriginal` field. Instead, `ActivityHandle` has an additional method
> `restoreOriginalOptions`.

The bigger one, in `activity_handle.rb`. `update_options` loses the kwarg and
both `ArgumentError` guards; a new `restore_original_options(rpc_options: nil)`
sends the same request with an empty options message, an empty field mask, and
`restore_original: true`.

Same reasoning as Java: the proto says that flag *"cannot be combined with any
other option; if you supply restore_original together with other options, the
request will be rejected"* — so the kwarg let a caller build a request the
server refuses.

### 3. Conversion moves into the interceptor terminus — mirrors Comment J

> `UpdateActivityOptionsOutput` should have the final options object, not Proto
> object. The conversion should happen inside the root interceptor.

`implementation.rb#update_activity_options` now returns
`ActivityExecutionOptions._from_proto(resp.activity_options)` instead of the raw
proto, and `activity_handle.rb` no longer converts. Interceptors in the chain
now see the public type rather than the wire type.

### 4. Strip un-requested payload fields — mirrors Comment K

> We should remove payload fields that were not requested (to support
> older/buggy servers).

`describe_activity` clears `resp.input`, `resp.outcome`,
`resp.info.heartbeat_details`, and `resp.info.last_failure` when the
corresponding flag was false, so an older or buggy server cannot make the
`has_*?` predicates disagree with what was asked for.

## Test changes

Two tests deleted — `test_update_options_restore_original_exclusive` and
`test_update_options_requires_at_least_one_option` — because they asserted the
validation that change 2 removed.

**Worth a look before committing:** these were more thorough than the Java pair
that was deleted for the same reason. They wrapped the service stub to prove the
RPC was *never reached* when validation failed. That coverage is genuinely gone,
not relocated.

Three call sites updated to the new names.

## Where Ruby deliberately diverges

Four Java comments have no Ruby counterpart, for reasons checked rather than
assumed:

- **Comment C (`EncodedValues`)** — Ruby has no `Values` type, and
  `input(hints:)` / `heartbeat_details(hints:)` already return the whole array,
  which is the shape the Java change moves toward.
- **Comment E (null-coalescing)** — Ruby's protobuf returns `nil` for unset
  message fields rather than a default instance, so `@raw_description.outcome&.value`
  is required, not redundant.
- **Comment B (serialization context)** — Ruby's `DataConverter` has no context
  mechanism; nothing to attach.
- **Comments A, D, G, I** — no analogous structures: Ruby's `Description` stores
  only `@raw_description`, hints are a single value, `ActivityExecutionOptions`
  is not redundant there (Ruby's update input is kwargs, not a class), and Ruby's
  interceptor inputs have no options objects to hold.

Also not mirrored, because they came after the Ruby work:

- The two Java follow-ups (two more redundant presence guards; skipping the
  response copy when everything was requested).
- The `PauseActivityOptions` class. Ruby's `pause(reason = nil)` is a positional
  argument, so it has neither the `pause(null)` ambiguity problem nor an
  options-class convention to match.

## State

Uncommitted on `gmt/operator-commands`. Last verified green: 17 + 1 + 1 runs
across the three operator-command test files, 411 assertions, steep clean,
RuboCop clean across 191 files — but that was before the Java follow-ups, and
has not been re-run since.

The worktree also carries untracked files (`pr-desc.md`, `run-tests.sh`,
`run-all-tests.sh`, `temporalio/Cargo.lock.pre-optionc.bak`, and this file), so
avoid `git add -A` when committing.
