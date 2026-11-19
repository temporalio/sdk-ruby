#!/usr/bin/env bash
# Builds the gem for the Mac this runs on (arm64-darwin on Apple Silicon) into fork/dist, for the Ruby minor that is on PATH.
# Needs a Rust toolchain and protoc (set PROTOC, or have protoc on PATH).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

git submodule update --init temporalio/ext/sdk-core

PROTOC="${PROTOC:-$(command -v protoc || true)}"
if [ -z "$PROTOC" ]; then
  echo "protoc not found: install it (brew install protobuf) or set PROTOC to a protoc binary" >&2
  exit 1
fi
export PROTOC

# Leave the submodule at its pinned upstream commit when done, whether or not the build worked.
trap '"$ROOT/fork/apply-core-patches.sh" --reverse' EXIT
./fork/apply-core-patches.sh

# RUSTFLAGS from the environment replaces temporalio/ext/.cargo/config.toml's "--edition=2024" rustflag, which newer rustc
# versions reject as a duplicate on crates that already pass their own edition. Every crate here sets its own edition.
# The home directory is remapped so the binary does not embed it (Rust puts source paths in panic messages).
export RUSTFLAGS="${RUSTFLAGS:--C debuginfo=0 --remap-path-prefix=$HOME=/build}"

cd temporalio
# A Ruby extension leaves the rb_* symbols to the running Ruby (rb_sys's Makefile adds this for `rake compile`). The install
# name is set to a fixed one so the binary does not embed the absolute path it was linked at.
cargo rustc --release -p temporalio_bridge --lib -- \
  -C link-arg=-Wl,-undefined,dynamic_lookup \
  -C link-arg=-Wl,-install_name,temporalio_bridge.bundle
strip -x target/release/libtemporalio_bridge.dylib

ruby "$ROOT/fork/package_gem.rb" \
  "$(ruby -e 'puts Gem::Platform.local')" "$ROOT/fork/dist" \
  "$(ruby -e 'puts RUBY_VERSION[/\d+\.\d+/]')=target/release/libtemporalio_bridge.dylib"
