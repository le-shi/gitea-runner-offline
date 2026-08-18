#!/usr/bin/env bash
set -euo pipefail

lock_file="${1:-/opt/gitea-runner-offline/docker-cli.lock}"
default_version="${2:?default Docker CLI version is required}"

case "${TARGETARCH:-}" in
  amd64) download_arch=x86_64; checksum_field=2 ;;
  arm64) download_arch=aarch64; checksum_field=3 ;;
  *) echo "Unsupported Docker CLI architecture: ${TARGETARCH:-unset}" >&2; exit 1 ;;
esac

download_dir="$(mktemp -d)"
trap 'rm -rf "${download_dir}"' EXIT

while IFS='|' read -r version amd64_sha256 arm64_sha256; do
  case "${version}" in ''|'#'*) continue ;; esac
  expected_sha256="${amd64_sha256}"
  if [ "${checksum_field}" -eq 3 ]; then
    expected_sha256="${arm64_sha256}"
  fi

  archive="${download_dir}/docker-${version}-${download_arch}.tgz"
  extract_dir="${download_dir}/docker-${version}"
  curl --fail --location --retry 5 --retry-all-errors \
    "https://download.docker.com/linux/static/stable/${download_arch}/docker-${version}.tgz" \
    --output "${archive}"
  echo "${expected_sha256}  ${archive}" | sha256sum --check --strict

  mkdir -p "${extract_dir}" "/opt/docker/${version}/bin"
  tar -xzf "${archive}" -C "${extract_dir}" docker/docker
  install -m 0755 "${extract_dir}/docker/docker" "/opt/docker/${version}/bin/docker"

  major="${version%%.*}"
  ln -sfn "/opt/docker/${version}/bin/docker" "/usr/local/bin/docker${major}"
  "/opt/docker/${version}/bin/docker" --version
done < "${lock_file}"

test -x "/opt/docker/${default_version}/bin/docker"
ln -sfn "/opt/docker/${default_version}/bin/docker" /usr/local/bin/docker
docker --version
