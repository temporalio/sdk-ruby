#!/usr/bin/env bash
# Runs the full Ruby quality suite (rubocop, yard, steep, rust lint, compile, test) the way CI
# does, against the CLI release pinned in test/test.rb. No local server involved.
#
# Requires ruby, cargo and go on PATH — the harness compiles the native extension and spawns a
# Go kitchen-sink worker; a missing `go` shows up as ~70 Errno::ENOENT test errors.
#
# NOTE: not added to git (per working conventions).
set -euo pipefail

GEM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/temporalio" && pwd)"
cd "$GEM_DIR"

for tool in ruby cargo go; do
  command -v "$tool" >/dev/null || { echo "missing required tool: $tool" >&2; exit 1; }
done

env -u TEMPORAL_TEST_CLIENT_TARGET_HOST bundle exec rake
