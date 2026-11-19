#!/usr/bin/env bash
# Builds the Linux gems with Docker, each natively inside its own platform (no cross-compilation), into fork/dist.
# Usage: fork/build-linux-gems.sh [linux/arm64] [linux/amd64]     (default: both)
# On an Apple Silicon Mac, arm64 is native and amd64 runs under emulation (Rosetta with OrbStack), so it is slower.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

git submodule update --init temporalio/ext/sdk-core

platforms=("$@")
if [ ${#platforms[@]} -eq 0 ]; then platforms=(linux/arm64 linux/amd64); fi

for platform in "${platforms[@]}"; do
  echo "=== building for $platform"
  docker buildx build \
    --platform "$platform" \
    --build-arg "PROTOC_VERSION=$(tr -d '\n' < .protoc-version)" \
    -f fork/Dockerfile \
    --target gems \
    --output type=local,dest=fork/dist \
    .
done

ls -la fork/dist/*.gem
