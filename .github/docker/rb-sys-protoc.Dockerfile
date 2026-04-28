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

ARG GCC_VERSION=""

RUN if [ -n "$GCC_VERSION" ]; then \
      apt-get update && \
      apt-get install -y --no-install-recommends gcc-${GCC_VERSION} g++-${GCC_VERSION} && \
      rm -rf /var/lib/apt/lists/*; \
    fi

RUN touch /etc/rubybashrc && \
    if [ -n "$GCC_VERSION" ]; then \
      echo "export CC=gcc-${GCC_VERSION}" >> /etc/rubybashrc; \
      echo "export CXX=g++-${GCC_VERSION}" >> /etc/rubybashrc; \
      echo "export AR=gcc-ar-${GCC_VERSION}" >> /etc/rubybashrc; \
      echo "export CC_x86_64_unknown_linux_gnu=gcc-${GCC_VERSION}" >> /etc/rubybashrc; \
      echo "export CXX_x86_64_unknown_linux_gnu=g++-${GCC_VERSION}" >> /etc/rubybashrc; \
      echo "export CARGO_TARGET_X86_64_UNKNOWN_LINUX_GNU_LINKER=gcc-${GCC_VERSION}" >> /etc/rubybashrc; \
    fi

COPY --from=protoc /opt/protoc/bin/protoc /usr/local/bin/protoc
COPY --from=protoc /opt/protoc/include /usr/local/include

ENV PROTOC=/usr/local/bin/protoc
ENV PROTOC_INCLUDE=/usr/local/include
