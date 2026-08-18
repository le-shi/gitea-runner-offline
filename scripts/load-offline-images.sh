#!/usr/bin/env bash
set -euo pipefail

archive_root="${1:-/opt/offline-images}"
test -S /var/run/docker.sock || {
  echo "Docker socket is required; mount it with -v /var/run/docker.sock:/var/run/docker.sock" >&2
  exit 1
}

(cd "${archive_root}" && sha256sum --check SHA256SUMS)
for archive in "${archive_root}"/*.tar; do
  docker load --input "${archive}"
done

echo "Loaded $(find "${archive_root}" -maxdepth 1 -name '*.tar' | wc -l | tr -d ' ') offline Docker images."
