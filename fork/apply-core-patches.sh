#!/usr/bin/env bash
# Applies fork/patches/*.patch to the sdk-core submodule (temporalio/ext/sdk-core). Safe to run more than once.
# With --reverse it takes them off again, leaving the submodule at its pinned upstream commit.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CORE="$ROOT/temporalio/ext/sdk-core"

if [ ! -f "$CORE/Cargo.toml" ]; then
  echo "sdk-core submodule is not checked out: run 'git submodule update --init temporalio/ext/sdk-core'" >&2
  exit 1
fi

# `patch` rather than `git apply`: inside the Docker build the submodule's .git file points at a directory that is not in the
# build context, which makes git treat it as a broken repository.
already_applied() { patch -d "$CORE" -p1 -R -f -s --dry-run < "$1" >/dev/null 2>&1; }

if [ "${1:-}" = "--reverse" ]; then
  for patch in $(ls -r "$ROOT"/fork/patches/*.patch); do
    if already_applied "$patch"; then
      patch -d "$CORE" -p1 -R -f -s < "$patch"
      echo "removed: $(basename "$patch")"
    fi
  done
  exit 0
fi

for patch in "$ROOT"/fork/patches/*.patch; do
  name="$(basename "$patch")"
  if already_applied "$patch"; then
    echo "already applied: $name"
  else
    patch -d "$CORE" -p1 -f -s < "$patch"
    echo "applied: $name"
  fi
done
