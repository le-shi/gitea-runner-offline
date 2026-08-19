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
ARG DOCKER_DEFAULT_VERSION=29.7.2

ENV MISE_DATA_DIR=/opt/mise \
    MISE_CACHE_DIR=/opt/offline-cache/mise \
    MISE_STATE_DIR=/opt/mise-state \
    MISE_CONFIG_FILE=/opt/gitea-runner-offline/mise.toml \
    RUNNER_TOOL_CACHE=/opt/hostedtoolcache \
    AGENT_TOOLSDIRECTORY=/opt/hostedtoolcache \
    RUN_TOOL_CACHE=/opt/hostedtoolcache \
    ACT_TOOLSDIRECTORY=/opt/acttoolcache \
    RUNNER_TEMP=/opt/runner-temp \
    ImageOS=debian12 \
    IMAGE_OS=debian12 \
    LSB_RELEASE=12 \
    NPM_CONFIG_CACHE=/opt/offline-cache/npm \
    MAVEN_OPTS=-Dmaven.repo.local=/opt/offline-cache/maven \
    GOPATH=/opt/offline-cache/go \
    GOMODCACHE=/opt/offline-cache/go/pkg/mod \
    CARGO_HOME=/opt/offline-cache/cargo \
    GEM_HOME=/opt/offline-cache/ruby/gems \
    GEM_SPEC_CACHE=/opt/offline-cache/ruby/specs \
    PATH=/opt/venvs/python-tools/bin:/opt/offline-cache/go/bin:/opt/offline-cache/cargo/bin:/opt/offline-cache/ruby/gems/bin:/opt/mise/shims:/opt/mise/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

RUN set -eux; \
    apt-get update; \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      autoconf bash bison build-essential ca-certificates coreutils curl dirmngr file findutils gawk git git-lfs gnupg gzip jq \
      libdb-dev libffi-dev libgdbm-dev libgmp-dev libicu72 libncurses-dev libreadline-dev libssl-dev libyaml-dev \
      lsb-release openssh-client pipx pkg-config rsync skopeo sudo tar tini unzip wget xz-utils zip zlib1g-dev zstd; \
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
COPY scripts/populate-toolcache.sh /usr/local/bin/populate-offline-toolcache
COPY scripts/configure-job-compatibility.sh /usr/local/bin/configure-job-compatibility

RUN --mount=type=secret,id=GITHUB_TOKEN \
    set -eu; \
    chmod 0755 /usr/local/bin/install-offline-toolchains /usr/local/bin/populate-offline-toolcache /usr/local/bin/configure-job-compatibility; \
    if [ -s /run/secrets/GITHUB_TOKEN ]; then \
      export GITHUB_TOKEN="$(cat /run/secrets/GITHUB_TOKEN)" GH_TOKEN="$(cat /run/secrets/GITHUB_TOKEN)"; \
    fi; \
    /usr/local/bin/install-offline-toolchains \
      node@18.20.8 node@20.20.2 node@22.23.2 node@24.19.0

RUN --mount=type=secret,id=GITHUB_TOKEN \
    set -eu; \
    if [ -s /run/secrets/GITHUB_TOKEN ]; then \
      export GITHUB_TOKEN="$(cat /run/secrets/GITHUB_TOKEN)" GH_TOKEN="$(cat /run/secrets/GITHUB_TOKEN)"; \
    fi; \
    /usr/local/bin/install-offline-toolchains \
      python@3.10.21 python@3.11.16 python@3.12.14 python@3.13.15 python@3.14.7

RUN --mount=type=secret,id=GITHUB_TOKEN \
    set -eu; \
    if [ -s /run/secrets/GITHUB_TOKEN ]; then \
      export GITHUB_TOKEN="$(cat /run/secrets/GITHUB_TOKEN)" GH_TOKEN="$(cat /run/secrets/GITHUB_TOKEN)"; \
    fi; \
    /usr/local/bin/install-offline-toolchains \
      java@temurin-8.0.502+7 java@temurin-11.0.32+9 java@temurin-17.0.20+8 \
      java@temurin-21.0.12+8.0.LTS java@temurin-25.0.4+7.0.LTS

RUN --mount=type=secret,id=GITHUB_TOKEN \
    set -eu; \
    if [ -s /run/secrets/GITHUB_TOKEN ]; then \
      export GITHUB_TOKEN="$(cat /run/secrets/GITHUB_TOKEN)" GH_TOKEN="$(cat /run/secrets/GITHUB_TOKEN)"; \
    fi; \
    /usr/local/bin/install-offline-toolchains \
      go@1.22.12 go@1.23.12 go@1.24.13 go@1.25.13

RUN --mount=type=secret,id=GITHUB_TOKEN \
    set -eu; \
    if [ -s /run/secrets/GITHUB_TOKEN ]; then \
      export GITHUB_TOKEN="$(cat /run/secrets/GITHUB_TOKEN)" GH_TOKEN="$(cat /run/secrets/GITHUB_TOKEN)"; \
    fi; \
    /usr/local/bin/install-offline-toolchains rust@1.97.1

RUN --mount=type=secret,id=GITHUB_TOKEN \
    set -eu; \
    if [ -s /run/secrets/GITHUB_TOKEN ]; then \
      export GITHUB_TOKEN="$(cat /run/secrets/GITHUB_TOKEN)" GH_TOKEN="$(cat /run/secrets/GITHUB_TOKEN)"; \
    fi; \
    /usr/local/bin/install-offline-toolchains \
      ruby@3.2.11 ruby@3.3.12 ruby@3.4.10

RUN --mount=type=secret,id=GITHUB_TOKEN \
    set -eu; \
    if [ -s /run/secrets/GITHUB_TOKEN ]; then \
      export GITHUB_TOKEN="$(cat /run/secrets/GITHUB_TOKEN)" GH_TOKEN="$(cat /run/secrets/GITHUB_TOKEN)"; \
    fi; \
    /usr/local/bin/install-offline-toolchains \
      maven@3.9.16 gradle@8.14.5 bun@1.3.14 deno@2.9.5 uv@0.12.5 \
      terraform@1.15.8 kubectl@1.34.10 helm@3.21.4 kustomize@5.8.1 \
      cosign@2.6.5 syft@1.51.0 trivy@0.74.0 shellcheck@0.11.0 shfmt@3.13.1 yq@4.53.3

RUN set -eu; \
    /usr/local/bin/populate-offline-toolcache; \
    /usr/local/bin/configure-job-compatibility

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
RUN chmod 0755 /usr/local/bin/install-offline-actions; \
    /usr/local/bin/install-offline-actions /opt/gitea-runner-offline/actions.lock /root/.cache/act 1 14

RUN /usr/local/bin/install-offline-actions \
      /opt/gitea-runner-offline/actions.lock /root/.cache/act 15 28

RUN /usr/local/bin/install-offline-actions \
      /opt/gitea-runner-offline/actions.lock /root/.cache/act 29 42

RUN /usr/local/bin/install-offline-actions \
      /opt/gitea-runner-offline/actions.lock /root/.cache/act 43 56

COPY scripts/install-docker-tools.sh /usr/local/bin/install-offline-docker-tools
COPY docker-cli.lock /opt/gitea-runner-offline/docker-cli.lock
COPY scripts/install-docker-cli.sh /usr/local/bin/install-offline-docker-cli
COPY scripts/use-docker-version.sh /usr/local/bin/use-docker-version
RUN chmod 0755 /usr/local/bin/install-offline-docker-cli /usr/local/bin/use-docker-version; \
    /usr/local/bin/install-offline-docker-cli \
      /opt/gitea-runner-offline/docker-cli.lock "${DOCKER_DEFAULT_VERSION}"

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
COPY scripts/verify-job-environment.sh /usr/local/bin/verify-job-environment
RUN chmod 0755 /usr/local/bin/verify-offline-image /usr/local/bin/verify-offline-setup-actions /usr/local/bin/verify-offline-dependency-caches /usr/local/bin/verify-job-environment

COPY scripts/generate-capabilities.py /usr/local/bin/generate-offline-capabilities
COPY scripts/show-offline-capabilities.sh /usr/local/bin/show-offline-capabilities
RUN chmod 0755 /usr/local/bin/generate-offline-capabilities /usr/local/bin/show-offline-capabilities; \
    /usr/local/bin/generate-offline-capabilities; \
    /usr/local/bin/show-offline-capabilities

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
      io.gitea.runner.offline.capabilities="/opt/gitea-runner-offline/capabilities.json" \
      io.gitea.runner.offline.target-arch="${TARGETARCH}"

# Keep the upstream entrypoint and command unchanged.
VOLUME ["/data"]
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/run.sh"]
