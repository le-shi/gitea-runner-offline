#!/usr/bin/env bash
set -euo pipefail

config_file="${1:-/opt/gitea-runner-offline/mise.toml}"
export MISE_CONFIG_FILE="${config_file}"
export MISE_DATA_DIR="${MISE_DATA_DIR:-/opt/mise}"
export MISE_CACHE_DIR="${MISE_CACHE_DIR:-/opt/offline-cache/mise}"
export MISE_STATE_DIR="${MISE_STATE_DIR:-/opt/mise-state}"

mkdir -p "${MISE_DATA_DIR}" "${MISE_CACHE_DIR}" "${MISE_STATE_DIR}"
mise trust --yes "${config_file}"
attempt=1
while ! mise install --yes "$@"; do
  if [ "${attempt}" -ge 5 ]; then
    echo "Toolchain installation failed after ${attempt} attempts" >&2
    exit 1
  fi
  sleep "$((attempt * 10))"
  attempt="$((attempt + 1))"
done
mise reshim

# Record resolved versions because major/minor channels are resolved at build time.
mise ls --json > /opt/gitea-runner-offline/toolchains.resolved.json
