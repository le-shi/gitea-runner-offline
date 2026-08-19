#!/usr/bin/env sh
set -eu

required_commands="bash curl git git-lfs jq yq ssh rsync skopeo sudo wget gawk zstd gpg pipx tar unzip zip xz docker docker27 docker28 docker29 use-docker-version mise node npm python java go rustc cargo ruby gem rake rspec rubocop mvn gradle terraform kubectl helm kustomize cosign syft trivy shellcheck shfmt load-offline-images show-offline-capabilities verify-job-environment"
for command_name in ${required_commands}; do
  command -v "${command_name}" >/dev/null 2>&1 || {
    echo "Missing command: ${command_name}" >&2
    exit 1
  }
done

lock_file=/opt/gitea-runner-offline/actions.lock
cache_root=/root/.cache/act
test -s "${lock_file}"

expected_count="$(grep -Ev '^[[:space:]]*(#|$)' "${lock_file}" | wc -l | tr -d ' ')"
actual_count="$(find "${cache_root}" -mindepth 2 -maxdepth 2 -name .offline-source | wc -l | tr -d ' ')"

if [ "${expected_count}" != "${actual_count}" ]; then
  echo "Action cache mismatch: expected ${expected_count}, found ${actual_count}" >&2
  exit 1
fi

while IFS='|' read -r cache_name repository commit friendly_ref runtime_cache_key; do
  case "${cache_name}" in ''|'#'*) continue ;; esac
  repository_path="${repository%.git}"
  repository_path="${repository_path#*://}"
  repository_path="${repository_path#*/}"
  cache_key="${runtime_cache_key:-$(printf '%s' "${repository_path}" | sed 's|[^A-Za-z0-9_.-]|-|g')}"
  bare_repository="${cache_root}/${cache_key}.git"
  requested_ref="${cache_name##*@}"
  test -d "${bare_repository}"
  resolved_commit="$(git --git-dir="${bare_repository}" rev-parse "refs/tags/${requested_ref}^{commit}")"
  test "${resolved_commit}" = "${commit}"
  exact_commit="$(git --git-dir="${bare_repository}" rev-parse "refs/tags/${friendly_ref}^{commit}")"
  test "${exact_commit}" = "${commit}"
done <"${lock_file}"

echo "Offline runner image verified: ${actual_count} Actions and required tools are present."

test -s /opt/gitea-runner-offline/toolchains.resolved.json
test -s /opt/gitea-runner-offline/toolcache.links.txt
capabilities=/opt/gitea-runner-offline/capabilities.json
test -s "${capabilities}"
jq -e '
  .schema_version == 1 and
  (.actions | length) == 56 and
  (.docker.available_cli | map(.version)) == ["27.5.1", "28.5.2", "29.7.2"] and
  .toolchains.yq == ["4.53.3"] and
  (.offline_images | length) == 2
' "${capabilities}" >/dev/null
show-offline-capabilities >/dev/null
test "${ACT_TOOLSDIRECTORY}" = /opt/acttoolcache
test "${RUNNER_TEMP}" = /opt/runner-temp
test "${ImageOS}" = debian12
for directory in /github/home /github/workflow /github/file_commands /opt/runner-temp; do
  test -d "${directory}"
  test -w "${directory}"
done
case "$(uname -m)" in
  x86_64) act_cache_arch=x64 ;;
  aarch64) act_cache_arch=arm64 ;;
  *) echo "Unsupported verification architecture: $(uname -m)" >&2; exit 1 ;;
esac
for version in 20.20.2 24.19.0; do
  test -L "/opt/acttoolcache/node/${version}/${act_cache_arch}"
done
git config --system --get-all safe.directory | grep -qxF '*'
test -d /opt/offline-cache/npm
test -s /opt/offline-cache/npm-packages/SHA256SUMS
test -d /opt/offline-cache/pip-wheelhouse
test -d /opt/offline-cache/maven
test -d /opt/offline-cache/go/pkg/mod
test -d /opt/offline-cache/cargo/registry
test -d /opt/offline-cache/ruby/gems/cache
test -s /opt/offline-images/images.resolved.txt
test -s /opt/offline-images/SHA256SUMS
(cd /opt/offline-images && sha256sum --check SHA256SUMS)
offline_image_count="$(find /opt/offline-images -maxdepth 1 -name '*.tar' | wc -l | tr -d ' ')"
test "${offline_image_count}" -eq 2

for cache_name in node Python go Java_Temurin-Hotspot_jdk; do
  test -d "/opt/hostedtoolcache/${cache_name}"
done
toolcache_count="$(find /opt/hostedtoolcache -type l | wc -l | tr -d ' ')"
test "${toolcache_count}" -eq 18

verify_toolchain() {
  selector="$1"
  executable="$2"
  shift 2
  printf 'Verifying %-22s ' "${selector}"
  MISE_OFFLINE=1 mise exec "${selector}" -- "${executable}" "$@"
}

for selector in node@18.20.8 node@20.20.2 node@22.23.2 node@24.19.0; do
  verify_toolchain "${selector}" node --version
done
for selector in python@3.10.21 python@3.11.16 python@3.12.14 python@3.13.15 python@3.14.7; do
  verify_toolchain "${selector}" python --version
done
for selector in java@temurin-8.0.502+7 java@temurin-11.0.32+9 java@temurin-17.0.20+8 java@temurin-21.0.12+8.0.LTS java@temurin-25.0.4+7.0.LTS; do
  verify_toolchain "${selector}" java -version
done
for selector in go@1.22.12 go@1.23.12 go@1.24.13 go@1.25.13; do
  verify_toolchain "${selector}" go version
done
verify_toolchain rust@1.97.1 rustc --version
for version in 3.2.11 3.3.12 3.4.10; do
  verify_toolchain "ruby@${version}" ruby --version
done

echo "Multi-version toolchains and dependency caches verified."

docker buildx version
docker compose version
docker-compose version
for version in 27.5.1 28.5.2 29.7.2; do
  output="$("/opt/docker/${version}/bin/docker" --version)"
  case "${output}" in
    *" ${version},"*) ;;
    *) echo "Expected Docker CLI ${version}, got: ${output}" >&2; exit 1 ;;
  esac
done
for major in 27 28 29; do
  use-docker-version "${major}" | grep -q " ${major}\."
  docker buildx version
  docker compose version
done
docker --version | grep -q ' 29.7.2,'
echo "Verified ${offline_image_count} architecture-native BuildKit/binfmt archives."
