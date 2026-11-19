# syntax=docker/dockerfile:1
#
# Builds the patched temporalio gem for the platform the image is built for, natively inside that platform:
#   linux/arm64 -> temporalio-<version>-aarch64-linux.gem
#   linux/amd64 -> temporalio-<version>-x86_64-linux.gem
# See fork/README.md. Build context is the repository root, with the sdk-core submodule checked out.
#
#   docker buildx build --platform linux/arm64 -f fork/Dockerfile --target gems --output type=local,dest=fork/dist .
ARG RUBY_VERSION=3.3
FROM ruby:${RUBY_VERSION}-bookworm AS build

# Rust 1.95 is what the pinned sdk-core's rust-toolchain.toml asks for. The protoc version is the one the repository pins
# (.protoc-version).
ARG RUST_VERSION=1.95.0
ARG PROTOC_VERSION=34.0
ARG TARGETARCH

RUN apt-get update \
 && apt-get install -y --no-install-recommends build-essential clang libclang-dev cmake pkg-config curl unzip ca-certificates git \
 && rm -rf /var/lib/apt/lists/*

ENV RUSTUP_HOME=/opt/rustup CARGO_HOME=/opt/cargo
ENV PATH=/opt/cargo/bin:${PATH}
RUN curl -fsSL https://sh.rustup.rs | sh -s -- -y --profile minimal --default-toolchain "${RUST_VERSION}"

RUN case "${TARGETARCH}" in \
      amd64) protoc_arch='x86_64' ;; \
      arm64) protoc_arch='aarch_64' ;; \
      *) echo "Unsupported TARGETARCH: ${TARGETARCH}" >&2; exit 1 ;; \
    esac \
 && curl -fsSL -o /tmp/protoc.zip "https://github.com/protocolbuffers/protobuf/releases/download/v${PROTOC_VERSION}/protoc-${PROTOC_VERSION}-linux-${protoc_arch}.zip" \
 && unzip -q /tmp/protoc.zip -d /usr/local \
 && rm /tmp/protoc.zip
ENV PROTOC=/usr/local/bin/protoc

WORKDIR /src
COPY . .
RUN ./fork/apply-core-patches.sh

# RUSTFLAGS from the environment replaces temporalio/ext/.cargo/config.toml's "--edition=2024" rustflag, which newer rustc
# versions reject as a duplicate on crates that already pass their own edition. Every crate here sets its own edition.
ENV RUSTFLAGS="-C debuginfo=0"
WORKDIR /src/temporalio
RUN cargo build --release -p temporalio_bridge \
 && strip --strip-unneeded target/release/libtemporalio_bridge.so

RUN ruby /src/fork/package_gem.rb \
      "$(ruby -e 'puts Gem::Platform.local')" /out \
      "$(ruby -e 'puts RUBY_VERSION[/\d+\.\d+/]')=target/release/libtemporalio_bridge.so"

FROM scratch AS gems
COPY --from=build /out /
