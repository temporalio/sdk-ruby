#!/usr/bin/env bash
# Runs the SAA operator-command tests on gmt/operator-commands.
#
# No server setup: with TEMPORAL_TEST_CLIENT_TARGET_HOST unset, the harness downloads and starts
# the CLI release pinned in test/test.rb (dev_server_download_version) — the same path CI takes.
# Do not point this at a hand-built server; local runs and CI should exercise the identical binary.
#
# NOTE: not added to git (per working conventions).
set -euo pipefail

GEM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/temporalio" && pwd)"
cd "$GEM_DIR"

env -u TEMPORAL_TEST_CLIENT_TARGET_HOST \
  bundle exec rake test TEST='test/client_activity_operator_commands*_test.rb'
