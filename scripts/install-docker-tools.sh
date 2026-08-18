#!/usr/bin/env bash
set -euo pipefail

buildx_version="${1:?buildx version is required}"
compose_version="${2:?compose version is required}"

case "${TARGETARCH:-}" in
  amd64)
    buildx_arch=amd64
    compose_arch=x86_64
    ;;
  arm64)
    buildx_arch=arm64
    compose_arch=aarch64
    ;;
  *) echo "Unsupported Docker tool architecture: ${TARGETARCH:-unset}" >&2; exit 1 ;;
esac

plugin_dir=/usr/local/lib/docker/cli-plugins
download_dir="$(mktemp -d)"
trap 'rm -rf "${download_dir}"' EXIT
mkdir -p "${plugin_dir}"

buildx_name="buildx-${buildx_version}.linux-${buildx_arch}"
buildx_base="https://github.com/docker/buildx/releases/download/${buildx_version}"
curl --fail --location --retry 5 --retry-all-errors \
  "${buildx_base}/${buildx_name}" --output "${download_dir}/${buildx_name}"
curl --fail --location --retry 5 --retry-all-errors \
  "${buildx_base}/checksums.txt" --output "${download_dir}/buildx-checksums.txt"
(cd "${download_dir}" && grep " ${buildx_name}$" buildx-checksums.txt | sha256sum --check)
install -m 0755 "${download_dir}/${buildx_name}" "${plugin_dir}/docker-buildx"

compose_name="docker-compose-linux-${compose_arch}"
compose_base="https://github.com/docker/compose/releases/download/${compose_version}"
curl --fail --location --retry 5 --retry-all-errors \
  "${compose_base}/${compose_name}" --output "${download_dir}/${compose_name}"
curl --fail --location --retry 5 --retry-all-errors \
  "${compose_base}/${compose_name}.sha256" --output "${download_dir}/${compose_name}.sha256"
(cd "${download_dir}" && sha256sum --check "${compose_name}.sha256")
install -m 0755 "${download_dir}/${compose_name}" "${plugin_dir}/docker-compose"
ln -s "${plugin_dir}/docker-compose" /usr/local/bin/docker-compose

docker buildx version
docker compose version
