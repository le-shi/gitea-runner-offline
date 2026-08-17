# syntax=docker/dockerfile:1.7
ARG RUNNER_IMAGE=gitea/runner:3.0
FROM ${RUNNER_IMAGE}

USER root

ARG RUNNER_IMAGE
ARG TARGETARCH

# Support the package managers used by current and potential future runner bases.
RUN set -eux; \
    if command -v apk >/dev/null 2>&1; then \
      apk add --no-cache bash ca-certificates coreutils curl findutils git git-lfs gzip jq openssh-client rsync tar unzip xz zip; \
    elif command -v apt-get >/dev/null 2>&1; then \
      apt-get update; \
      DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        bash ca-certificates coreutils curl findutils git git-lfs gzip jq openssh-client rsync tar unzip xz-utils zip; \
      rm -rf /var/lib/apt/lists/*; \
    else \
      echo "Unsupported package manager in ${RUNNER_IMAGE}" >&2; \
      exit 1; \
    fi; \
    git lfs install --system; \
    update-ca-certificates

COPY actions.lock /opt/gitea-runner-offline/actions.lock
COPY scripts/install-actions.sh /usr/local/bin/install-offline-actions
COPY scripts/verify-image.sh /usr/local/bin/verify-offline-image

# Populate the path used by act_runner/gitea-runner in the target environment.
# The lock file pins every repository to an immutable commit SHA.
RUN chmod 0755 /usr/local/bin/install-offline-actions /usr/local/bin/verify-offline-image; \
    /usr/local/bin/install-offline-actions /opt/gitea-runner-offline/actions.lock /root/.cache/act; \
    /usr/local/bin/verify-offline-image

LABEL org.opencontainers.image.title="Gitea Runner Offline" \
      org.opencontainers.image.description="Gitea Runner 3.0 with common Actions and delivery tools preloaded" \
      org.opencontainers.image.source="https://github.com/le-shi/gitea-runner-offline" \
      io.gitea.runner.offline.action-cache="/root/.cache/act" \
      io.gitea.runner.offline.target-arch="${TARGETARCH}"

# Keep the upstream entrypoint and command unchanged.
