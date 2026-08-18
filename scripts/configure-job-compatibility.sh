#!/usr/bin/env bash
set -euo pipefail

export MISE_CONFIG_FILE=/opt/gitea-runner-offline/mise.toml
act_toolcache="${ACT_TOOLSDIRECTORY:-/opt/acttoolcache}"

case "${TARGETARCH:-}" in
  amd64) cache_arch=x64 ;;
  arm64) cache_arch=arm64 ;;
  *) echo "Unsupported act tool-cache architecture: ${TARGETARCH:-unset}" >&2; exit 1 ;;
esac

# act uses this cache for the Node runtimes that execute JavaScript Actions.
for version in 20.20.2 24.19.0; do
  source_dir="$(mise where "node@${version}")"
  destination="${act_toolcache}/node/${version}/${cache_arch}"
  mkdir -p "$(dirname "${destination}")"
  ln -s "${source_dir}" "${destination}"
  touch "${destination}.complete"
done

# Common Actions assume these writable GitHub Hosted Runner paths exist.
mkdir -p \
  /github/home \
  /github/workflow \
  /github/file_commands \
  "${RUNNER_TEMP:-/opt/runner-temp}"
chmod 0777 \
  /github \
  /github/home \
  /github/workflow \
  /github/file_commands \
  "${RUNNER_TEMP:-/opt/runner-temp}"

# Mounted workspaces frequently have a UID/GID that differs from the container.
git config --system --add safe.directory '*'
