FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

ARG MISE_VERSION=2026.6.1
ARG TARGETARCH

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl \
    && case "${TARGETARCH}" in \
      amd64) mise_arch="x64" ;; \
      arm64) mise_arch="arm64" ;; \
      *) echo "Unsupported architecture: ${TARGETARCH}" >&2; exit 1 ;; \
    esac \
    && curl -fsSL "https://github.com/jdx/mise/releases/download/v${MISE_VERSION}/mise-v${MISE_VERSION}-linux-${mise_arch}" -o /usr/local/bin/mise \
    && chmod +x /usr/local/bin/mise \
    && echo 'eval "$(mise activate bash)"' > /etc/profile.d/mise.sh \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

ENV MISE_YES=1
