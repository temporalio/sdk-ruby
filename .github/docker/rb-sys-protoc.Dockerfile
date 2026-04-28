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
ARG DEFAULT_CC=""
ARG DEFAULT_CXX=""
ARG DEFAULT_AR=""
ARG X86_64_UNKNOWN_LINUX_GNU_CC=""
ARG X86_64_UNKNOWN_LINUX_GNU_CXX=""
ARG X86_64_UNKNOWN_LINUX_GNU_LINKER=""

RUN if [ -n "$EXTRA_APT_PACKAGES" ]; then \
      apt-get update && \
      apt-get install -y --no-install-recommends $EXTRA_APT_PACKAGES && \
      rm -rf /var/lib/apt/lists/*; \
    fi

RUN touch /etc/rubybashrc && \
    if [ -n "$DEFAULT_CC" ]; then echo "export CC=$DEFAULT_CC" >> /etc/rubybashrc; fi && \
    if [ -n "$DEFAULT_CXX" ]; then echo "export CXX=$DEFAULT_CXX" >> /etc/rubybashrc; fi && \
    if [ -n "$DEFAULT_AR" ]; then echo "export AR=$DEFAULT_AR" >> /etc/rubybashrc; fi && \
    if [ -n "$X86_64_UNKNOWN_LINUX_GNU_CC" ]; then echo "export CC_x86_64_unknown_linux_gnu=$X86_64_UNKNOWN_LINUX_GNU_CC" >> /etc/rubybashrc; fi && \
    if [ -n "$X86_64_UNKNOWN_LINUX_GNU_CXX" ]; then echo "export CXX_x86_64_unknown_linux_gnu=$X86_64_UNKNOWN_LINUX_GNU_CXX" >> /etc/rubybashrc; fi && \
    if [ -n "$X86_64_UNKNOWN_LINUX_GNU_LINKER" ]; then echo "export CARGO_TARGET_X86_64_UNKNOWN_LINUX_GNU_LINKER=$X86_64_UNKNOWN_LINUX_GNU_LINKER" >> /etc/rubybashrc; fi

COPY --from=protoc /opt/protoc/bin/protoc /usr/local/bin/protoc
COPY --from=protoc /opt/protoc/include /usr/local/include

ENV PROTOC=/usr/local/bin/protoc
ENV PROTOC_INCLUDE=/usr/local/include
