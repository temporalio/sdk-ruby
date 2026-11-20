# Fork notes: heartbeat timeouts left to the server

This fork is upstream [temporalio/sdk-ruby](https://github.com/temporalio/sdk-ruby) `v1.11.0` plus one opt-in worker
option. The gem version is **`1.11.0`, deliberately the same as upstream's**: an application's `Gemfile.lock` and bundix
`gemset.nix` then still resolve from rubygems.org (`bundle add`, `bundle update` and bundix keep working), and the application
only swaps in these gem files in place of the downloaded ones (see "Using the gems"). A distinct version such as `1.11.0.1`
would make every later `bundle lock` fail looking for a gem that is not on rubygems.org. Releases are tagged
`v1.11.0-heartbeat.N` to tell them apart.

## What it changes

`Temporalio::Worker.new(..., disable_local_heartbeat_timeout_for_activities: true)`.

By default the SDK core runs its own heartbeat timer for every activity. It resets only when a heartbeat made through the
activity's own context (`Activity::Context#heartbeat`) is acknowledged. If none is acknowledged for the activity's heartbeat
timeout plus about 5 seconds (`local_timeout_buffer_for_activities`), the core cancels the activity as timed out and
**discards its result** (`known_not_found`, "no need to report activities which we already know the server doesn't care
about"), even if the server is still receiving heartbeats for it.

That breaks workers that heartbeat from somewhere else, for example a separate process using the heartbeat-by-ID API so that a
native call holding the GVL cannot starve the heartbeat. With the option on, the core does not run the heartbeat timer, so
only the server enforces heartbeat timeouts. The local start-to-close timer is unchanged. The default is `false`: nothing
changes unless a worker asks for it.

A runnable reproduction: <https://github.com/fivetran-ryanrapp/temporalio-ruby-heartbeat-repro>.

## Where the change lives

- Ruby and the bridge (`temporalio/lib`, `temporalio/sig`, `temporalio/ext/src/worker.rs`) are changed in the tree.
- The `sdk-core` change is `fork/patches/0001-sdk-core-disable-local-heartbeat-timeout.patch`. It is applied to the pinned
  submodule at build time by `fork/apply-core-patches.sh`, so the submodule stays on upstream's commit and no second fork of
  `sdk-core` is needed. It adds `WorkerConfig::disable_local_heartbeat_timeout_for_activities` and two unit tests.
- Tests: the two unit tests are in the patch (run them in `temporalio/ext/sdk-core` after applying it:
  `cargo test -p temporalio-sdk-core --lib worker::activities`). Two Ruby tests are in `temporalio/test/worker_activity_test.rb`
  (`test_local_heartbeat_timeout_cancels_activity_heartbeated_from_elsewhere` and
  `test_disable_local_heartbeat_timeout_for_activities`); they need the repository's test harness.
- The gems ship upstream's `rbi/` with two fixes applied at packaging time by `fork/patch_rbi.rb` (the repository's `rbi/` is
  untouched): `Google::Protobuf::Map` and `RepeatedField` get type arguments, and the keyword-argument `overload` signatures on
  `Workflow.upsert_memo` are dropped. Without them an application that runs `srb tc` over a Tapioca-generated gem RBI (which
  merges the shipped RBIs) fails with a few hundred errors.

## Building the gems

Gems are precompiled, one per platform, in the same layout as upstream's. Each carries the bridge for one Ruby minor (3.3 by
default) and requires exactly that minor.

| Gem | Built by |
|---|---|
| `temporalio-1.11.0-arm64-darwin.gem` | `fork/build-macos-gem.sh`, natively on the Mac. Needs Rust and `protoc`. |
| `temporalio-1.11.0-aarch64-linux.gem` | `fork/build-linux-gems.sh linux/arm64`, in Docker. |
| `temporalio-1.11.0-x86_64-linux.gem` | `fork/build-linux-gems.sh linux/amd64`, in Docker. |

```sh
git submodule update --init temporalio/ext/sdk-core
fork/build-linux-gems.sh            # both Linux gems into fork/dist
fork/build-macos-gem.sh             # the macOS gem into fork/dist
```

- The Dockerfile (`fork/Dockerfile`) builds natively inside each platform, with no cross-compiling. On an Apple Silicon Mac,
  arm64 is native and amd64 runs under emulation (Rosetta with OrbStack), so it is slower. Both use Rust 1.95 and the protoc
  version in `.protoc-version`.
- Another Ruby minor: `docker buildx build --build-arg RUBY_VERSION=3.4 ...` for Linux; the macOS script uses the Ruby on `PATH`.
- Not built: musl (Alpine), Intel Mac, Windows.

## Using the gems

Copy the three `.gem` files into `vendor/cache` and install locally. Bundler picks the one that matches the platform:

```sh
bundle lock --add-platform arm64-darwin aarch64-linux x86_64-linux
bundle install --local
```

```ruby
# Gemfile
gem 'temporalio', '1.11.0'
```

```ruby
worker = Temporalio::Worker.new(
  client:, task_queue: 'my-queue', activities: [MyActivity],
  disable_local_heartbeat_timeout_for_activities: true
)
```

## Moving to a newer upstream release

1. Rebase this branch on the new upstream tag and update the submodule to the commit that tag pins.
2. `fork/apply-core-patches.sh`. If it conflicts, redo the change in `temporalio/ext/sdk-core` (it is small: one config field,
   threaded to where `ActivityLocalTimers::new` is called), then
   `git -C temporalio/ext/sdk-core diff > fork/patches/0001-sdk-core-disable-local-heartbeat-timeout.patch`.
3. Check that `temporalio/lib/temporalio/version.rb` matches the upstream release (do not add a fourth number, see the top of
   this file), rebuild the gems, and check `fork/patch_rbi.rb` still leaves no bare `Google::Protobuf::Map`/`RepeatedField`.

If upstream adds an equivalent option, drop the patch and use theirs.
