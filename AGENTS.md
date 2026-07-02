# Contributor Guidance for `sdk-ruby`

This repository contains the Temporal Ruby SDK. Keep this file as a compact operating guide for agents; use `README.md` and `CONTRIBUTING.md` for full contributor detail.

## Scope

- Run Ruby SDK commands from `temporalio/`.
- `temporalio/ext/sdk-core/` has its own `AGENTS.md`; follow it for Core changes.
- Ignore generated/build output such as `temporalio/doc/`, `temporalio/pkg/`, `temporalio/target/`, `temporalio/tmp/`, `target/`, and `.bundle/`.

## Repo Map

- `temporalio/lib/temporalio/` - Ruby SDK implementation.
- `temporalio/sig/` - RBS signatures.
- `temporalio/rbi/` - Sorbet RBI signatures.
- `temporalio/test/` - Minitest suite and helpers.
- `temporalio/ext/src/` - Rust extension bridge.
- `temporalio/extra/` - generators and support scripts.
- `temporalio/ext/sdk-core/` - embedded Temporal Core SDK.

## Commands

Run from `temporalio/`.

```bash
bundle exec rake test
TEMPORAL_SORBET_RUNTIME_CHECK=1 bundle exec rake test
bundle exec rake rubocop
bundle exec rake steep
bundle exec rake proto:generate
bundle exec rake proto:check_generated
bundle exec rake
```

Target tests with `TESTOPTS`:

```bash
bundle exec rake test TESTOPTS="--name=test_some_method"
bundle exec rake test TESTOPTS="--name=/SomeClassName/"
TEMPORAL_SORBET_RUNTIME_CHECK=1 bundle exec rake test TESTOPTS="--name=test_some_method"
```

Run `bundle exec rake compile` after native bridge changes, `bundle exec rake rust_lint` after Rust bridge changes, `bundle exec rake yard` for public API docs, and `bundle exec rake rbs:install_collection` if Steep lacks its RBS collection. The default `bundle exec rake` runs RuboCop, YARD, RBS collection install, Steep, Rust bridge lint, compile, and the full Minitest suite; it does not enable Sorbet runtime validation.

## Environment

- Ruby `>= 3.3.0` is required by the gemspec; RuboCop targets Ruby 3.3.
- Tests start a local Temporal dev server by default. To use an existing server, set `TEMPORAL_TEST_CLIENT_TARGET_HOST` and optionally `TEMPORAL_TEST_CLIENT_TARGET_NAMESPACE`.
- Proto generation requires `protoc >= 34.0` and `protoc-gen-rbi`. From `temporalio/`, install the RBI plugin with `go install github.com/coinbase/protoc-gen-rbi@$(cat ../.protoc-gen-rbi-version)`, or set `PROTOC_GEN_RBI` to an executable path.

## API And Types

- Public API changes usually need tests, YARD/README updates, RBS, RBI, and a `CHANGELOG.md` entry when user-facing.
- Keep RBS in `temporalio/sig/` and RBI in `temporalio/rbi/` in sync with Ruby implementation changes.
- RBS is checked with `bundle exec rake steep`.
- RBI is validated by regular RBI parse/coverage tests and, when enabled, `TEMPORAL_SORBET_RUNTIME_CHECK=1 bundle exec rake test`, which applies RBI signatures at runtime through `test/support/sig_applicator.rb`.
- Do not increase manual RBI `T.untyped` or `T.anything` usage just to satisfy Sorbet. Use concrete types; only update the ratchet when usage decreases.
- When tests intentionally pass the wrong type, use `SigApplicator.suppress_errors` narrowly.
- Preserve compatibility-sensitive names and shapes: workflow names, activity names, payloads, errors, and option keywords.
- Activities and workflows receive payload arguments positionally. Activities cannot accept keyword arguments.
- Add converter hints (`arg_hints`, `result_hint`, definition-level hints) when a new API path needs typed payload conversion.

## Workflow Rules

Workflow code must be deterministic. Do not add workflow code that performs IO, reads external mutable state, uses system time (`Time.now`, `Date.today`), random calls (`Kernel.rand`, `Random.new`), threads, Ruby mutexes/queues, blocking synchronization, or non-workflow loggers/metrics.

Use workflow-safe APIs instead: `Temporalio::Workflow.now`, `random`, `sleep`, `timeout`, `wait_condition`, `logger`, `metric_meter`, `Temporalio::Workflow::Future`, `Temporalio::Workflow::Mutex`, `Queue`, and `SizedQueue`.

Keep `wait_condition` blocks side-effect free. For workflow logic changes that could affect existing histories, use `patched` / `deprecate_patch` or add replay coverage with `Temporalio::Worker::WorkflowReplayer`.

## Activity Rules

- Prefer class-based activities inheriting from `Temporalio::Activity::Definition`.
- Activities may perform IO, but should be idempotent or otherwise retry-safe.
- Long-running activities should heartbeat regularly and set a heartbeat timeout when scheduled.
- Respect cancellation from `Temporalio::Activity::Context.current.cancellation`; do not accidentally swallow cancellation exceptions.
- Reused activity instances may be shared across attempts. Keep mutable instance state thread-safe or avoid it.

## Testing Rules

- Tests use Minitest. New tests should `require 'test'` and inherit from the repository `Test` base class.
- Prefer helpers such as `env.client`, `execute_workflow`, `assert_eventually`, and `assert_eventually_task_fail`.
- Use `Temporalio::Testing::ActivityEnvironment` for activity unit tests.
- Use unique task queues and workflow/activity IDs, commonly with `SecureRandom.uuid`.
- Run workers inside `worker.run` blocks so shutdown is scoped.
- Avoid real sleeps. Prefer server-visible conditions, queues, `assert_eventually`, cancellation tokens, or time skipping.
- Use `start_time_skipping` only for workflow time behavior; it is not safe for independent parallel tests.
- Clean up schedules, Nexus endpoints, workers, subprocesses, and external resources in `ensure` blocks or existing helpers.

## Generated Code

- Do not hand-edit generated protobuf, service, bridge API, RBS, or RBI files.
- The source of truth for generated paths is `temporalio/extra/proto_gen.rb::GENERATED_PATHS`.
- Regenerate with `bundle exec rake proto:generate`.
- Verify generated output with `bundle exec rake proto:check_generated`.

## Review Checklist

- Targeted tests cover the changed behavior.
- Run `bundle exec rake rubocop`.
- Run `bundle exec rake steep` for RBS/API changes.
- Run `TEMPORAL_SORBET_RUNTIME_CHECK=1 bundle exec rake test` for RBI/API changes.
- Run `bundle exec rake proto:check_generated` for proto/generated changes.
- Run `bundle exec rake compile` and `bundle exec rake rust_lint` for bridge changes.
- Run `bundle exec rake yard` and update docs/changelog for public user-facing changes.
