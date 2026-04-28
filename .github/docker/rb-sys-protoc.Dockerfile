ARG BASE_IMAGE=debian:bookworm-slim
FROM --platform=$BUILDPLATFORM debian:bookworm-slim AS protoc

ARG TARGETARCH
ARG PROTOC_VERSION

RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl unzip && rm -rf /var/lib/apt/lists/*

RUN case "$TARGETARCH" in \
      amd64) protoc_arch='x86_64' ;; \
      arm64) protoc_arch='aarch_64' ;; \
      *) echo "Unsupported TARGETARCH: $TARGETARCH" >&2; exit 1 ;; \
    esac && \
    curl -fsSL -o /tmp/protoc.zip "https://github.com/protocolbuffers/protobuf/releases/download/v${PROTOC_VERSION}/protoc-${PROTOC_VERSION}-linux-${protoc_arch}.zip" && \
    unzip /tmp/protoc.zip -d /opt/protoc && \
    rm /tmp/protoc.zip

FROM ${BASE_IMAGE}

ARG EXTRA_APT_PACKAGES=""

RUN if [ -n "$EXTRA_APT_PACKAGES" ]; then \
      apt-get update && \
      apt-get install -y --no-install-recommends $EXTRA_APT_PACKAGES && \
      rm -rf /var/lib/apt/lists/*; \
    fi

COPY --from=protoc /opt/protoc/bin/protoc /usr/local/bin/protoc
COPY --from=protoc /opt/protoc/include /usr/local/include

ENV PROTOC=/usr/local/bin/protoc
ENV PROTOC_INCLUDE=/usr/local/include
