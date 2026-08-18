#!/usr/bin/env bash
set -euo pipefail

seed_file="${1:-/opt/gitea-runner-offline/dependency-seeds/node-packages.txt}"
tarball_root="${2:-/opt/offline-cache/npm-packages}"
global_node_modules="$(MISE_OFFLINE=1 mise exec node@24.19.0 -- npm root --global)"

mkdir -p "${tarball_root}"
while IFS= read -r package_spec; do
  case "${package_spec}" in ''|'#'*) continue ;; esac
  package_name="${package_spec%@*}"
  package_path="${global_node_modules}/${package_name}"
  test -d "${package_path}" || {
    echo "Global npm package is missing: ${package_spec}" >&2
    exit 1
  }
  MISE_OFFLINE=1 mise exec node@24.19.0 -- npm pack \
    --ignore-scripts --pack-destination "${tarball_root}" "${package_path}" >/dev/null
done < "${seed_file}"

find "${tarball_root}" -maxdepth 1 -name '*.tgz' -type f -print0 | sort -z | xargs -0 sha256sum \
  > "${tarball_root}/SHA256SUMS"
