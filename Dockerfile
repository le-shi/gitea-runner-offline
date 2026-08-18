# syntax=docker/dockerfile:1.7
ARG RUNNER_IMAGE=gitea/runner:3.0
FROM ${RUNNER_IMAGE} AS runner-source

FROM debian:bookworm-slim

USER root

ARG RUNNER_IMAGE
ARG TARGETARCH
ARG MISE_VERSION=v2026.8.6
ARG BUILDX_VERSION=v0.36.1
ARG COMPOSE_VERSION=v5.5.0

ENV MISE_DATA_DIR=/opt/mise \
    MISE_CACHE_DIR=/opt/offline-cache/mise \
    MISE_STATE_DIR=/opt/mise-state \
    MISE_CONFIG_FILE=/opt/gitea-runner-offline/mise.toml \
    RUNNER_TOOL_CACHE=/opt/hostedtoolcache \
    AGENT_TOOLSDIRECTORY=/opt/hostedtoolcache \
    NPM_CONFIG_CACHE=/opt/offline-cache/npm \
    MAVEN_OPTS=-Dmaven.repo.local=/opt/offline-cache/maven \
    GOPATH=/opt/offline-cache/go \
    GOMODCACHE=/opt/offline-cache/go/pkg/mod \
    CARGO_HOME=/opt/offline-cache/cargo \
    GEM_HOME=/opt/offline-cache/ruby/gems \
    GEM_SPEC_CACHE=/opt/offline-cache/ruby/specs \
    DOTNET_ROOT=/opt/dotnet/10 \
    PATH=/opt/venvs/python-tools/bin:/opt/offline-cache/go/bin:/opt/offline-cache/cargo/bin:/opt/offline-cache/ruby/gems/bin:/opt/mise/shims:/opt/mise/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

RUN set -eux; \
    apt-get update; \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      autoconf bash bison build-essential ca-certificates coreutils curl file findutils git git-lfs gzip jq \
      libdb-dev libffi-dev libgdbm-dev libgmp-dev libicu72 libncurses-dev libreadline-dev libssl-dev libyaml-dev \
      openssh-client pkg-config rsync skopeo tar tini unzip xz-utils zip zlib1g-dev docker.io; \
    rm -rf /var/lib/apt/lists/*; \
    git lfs install --system; \
    update-ca-certificates

COPY --from=runner-source /usr/local/bin/gitea-runner /usr/local/bin/gitea-runner
COPY --from=runner-source /usr/local/bin/run.sh /usr/local/bin/run.sh

RUN set -eux; \
    case "${TARGETARCH}" in amd64) mise_arch=x64 ;; arm64) mise_arch=arm64 ;; *) echo "Unsupported architecture: ${TARGETARCH}" >&2; exit 1 ;; esac; \
    curl --fail --location --retry 5 \
      "https://github.com/jdx/mise/releases/download/${MISE_VERSION}/mise-${MISE_VERSION}-linux-${mise_arch}" \
      --output /usr/local/bin/mise; \
    chmod 0755 /usr/local/bin/mise; \
    mise --version

COPY actions.lock /opt/gitea-runner-offline/actions.lock
COPY mise.toml /opt/gitea-runner-offline/mise.toml
COPY dependency-seeds/ /opt/gitea-runner-offline/dependency-seeds/
COPY scripts/install-toolchains.sh /usr/local/bin/install-offline-toolchains
COPY scripts/install-dotnet.sh /usr/local/bin/install-offline-dotnet
COPY scripts/populate-toolcache.sh /usr/local/bin/populate-offline-toolcache

RUN --mount=type=secret,id=GITHUB_TOKEN \
    set -eu; \
    chmod 0755 /usr/local/bin/install-offline-toolchains /usr/local/bin/install-offline-dotnet /usr/local/bin/populate-offline-toolcache; \
    if [ -s /run/secrets/GITHUB_TOKEN ]; then \
      export GITHUB_TOKEN="$(cat /run/secrets/GITHUB_TOKEN)" GH_TOKEN="$(cat /run/secrets/GITHUB_TOKEN)"; \
    fi; \
    /usr/local/bin/install-offline-toolchains; \
    /usr/local/bin/install-offline-dotnet; \
    /usr/local/bin/populate-offline-toolcache

# Keep toolchain installation in a separate cacheable layer; dependency seeds
# change more frequently and should not force every language runtime to download.
COPY scripts/seed-dependencies.sh /usr/local/bin/seed-offline-dependencies
RUN --mount=type=secret,id=GITHUB_TOKEN \
    set -eu; \
    chmod 0755 /usr/local/bin/seed-offline-dependencies; \
    if [ -s /run/secrets/GITHUB_TOKEN ]; then \
      export GITHUB_TOKEN="$(cat /run/secrets/GITHUB_TOKEN)" GH_TOKEN="$(cat /run/secrets/GITHUB_TOKEN)"; \
    fi; \
    /usr/local/bin/seed-offline-dependencies

COPY scripts/package-offline-node-modules.sh /usr/local/bin/package-offline-node-modules
RUN chmod 0755 /usr/local/bin/package-offline-node-modules; \
    /usr/local/bin/package-offline-node-modules

# Populate the path used by act_runner/gitea-runner in the target environment.
# The lock file pins every repository to an immutable commit SHA.
COPY scripts/install-actions.sh /usr/local/bin/install-offline-actions
COPY scripts/patch-offline-actions.sh /usr/local/bin/patch-offline-actions
RUN chmod 0755 /usr/local/bin/install-offline-actions /usr/local/bin/patch-offline-actions; \
    /usr/local/bin/install-offline-actions /opt/gitea-runner-offline/actions.lock /root/.cache/act; \
    /usr/local/bin/patch-offline-actions

COPY scripts/install-docker-tools.sh /usr/local/bin/install-offline-docker-tools
RUN chmod 0755 /usr/local/bin/install-offline-docker-tools; \
    /usr/local/bin/install-offline-docker-tools "${BUILDX_VERSION}" "${COMPOSE_VERSION}"

COPY offline-images.lock /opt/gitea-runner-offline/offline-images.lock
COPY scripts/install-offline-images.sh /usr/local/bin/install-offline-images
COPY scripts/load-offline-images.sh /usr/local/bin/load-offline-images
COPY scripts/verify-offline-docker-images.sh /usr/local/bin/verify-offline-docker-images
RUN chmod 0755 /usr/local/bin/install-offline-images /usr/local/bin/load-offline-images /usr/local/bin/verify-offline-docker-images; \
    /usr/local/bin/install-offline-images

COPY scripts/verify-image.sh /usr/local/bin/verify-offline-image
COPY scripts/verify-setup-actions.sh /usr/local/bin/verify-offline-setup-actions
COPY scripts/verify-dependency-caches.sh /usr/local/bin/verify-offline-dependency-caches
RUN chmod 0755 /usr/local/bin/verify-offline-image /usr/local/bin/verify-offline-setup-actions /usr/local/bin/verify-offline-dependency-caches

ENV MISE_OFFLINE=1 \
    PIP_FIND_LINKS=/opt/offline-cache/pip-wheelhouse \
    PIP_NO_INDEX=1 \
    npm_config_offline=true \
    CARGO_NET_OFFLINE=true \
    GOPROXY=off

LABEL org.opencontainers.image.title="Gitea Runner Offline" \
      org.opencontainers.image.description="Gitea Runner 3.0 with Actions, multi-version toolchains, CLIs and dependency caches preloaded" \
      org.opencontainers.image.source="https://github.com/le-shi/gitea-runner-offline" \
      io.gitea.runner.offline.action-cache="/root/.cache/act" \
      io.gitea.runner.offline.dependency-cache="/opt/offline-cache" \
      io.gitea.runner.offline.toolchains="/opt/gitea-runner-offline/toolchains.resolved.json" \
      io.gitea.runner.offline.target-arch="${TARGETARCH}"

# Keep the upstream entrypoint and command unchanged.
VOLUME ["/data"]
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/run.sh"]
