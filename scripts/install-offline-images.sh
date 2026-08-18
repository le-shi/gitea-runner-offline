#!/usr/bin/env bash
set -euo pipefail

lock_file="${1:-/opt/gitea-runner-offline/offline-images.lock}"
archive_root="${2:-/opt/offline-images}"
manifest_file="${archive_root}/images.resolved.txt"

case "${TARGETARCH:-}" in
  amd64|arm64) ;;
  *) echo "Unsupported image architecture: ${TARGETARCH:-unset}" >&2; exit 1 ;;
esac

mkdir -p "${archive_root}"
: > "${manifest_file}"

while IFS='|' read -r archive_name source_image local_tag; do
  case "${archive_name}" in ''|'#'*) continue ;; esac
  archive_path="${archive_root}/${archive_name}-${TARGETARCH}.tar"
  digest="$(skopeo inspect --override-os linux --override-arch "${TARGETARCH}" --format '{{.Digest}}' "docker://${source_image}")"
  printf '%s|%s|%s|%s\n' "${archive_name}" "${source_image}" "${local_tag}" "${digest}" >> "${manifest_file}"
  skopeo copy --retry-times 5 --override-os linux --override-arch "${TARGETARCH}" \
    "docker://${source_image}@${digest}" "docker-archive:${archive_path}:${local_tag}"
done < "${lock_file}"

sha256sum "${archive_root}"/*.tar > "${archive_root}/SHA256SUMS"
