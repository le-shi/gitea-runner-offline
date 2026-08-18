#!/usr/bin/env sh
set -eu

required_commands="bash curl git git-lfs jq ssh rsync tar unzip zip xz docker mise node npm python java go dotnet rustc cargo mvn gradle terraform kubectl helm kustomize cosign syft trivy shellcheck shfmt"
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

echo "Offline runner image verified: ${actual_count} Actions and required tools are present."

test -s /opt/gitea-runner-offline/toolchains.resolved.json
test -s /opt/gitea-runner-offline/toolcache.links.txt
test -s /opt/gitea-runner-offline/offline-action-patches.txt
test -d /opt/offline-cache/npm
test -d /opt/offline-cache/pip-wheelhouse
test -d /opt/offline-cache/maven
test -d /opt/offline-cache/go/pkg/mod
test -d /opt/offline-cache/cargo/registry

for cache_name in node Python go Java_Temurin-Hotspot_jdk; do
  test -d "/opt/hostedtoolcache/${cache_name}"
done
toolcache_count="$(find /opt/hostedtoolcache -type l | wc -l | tr -d ' ')"
test "${toolcache_count}" -eq 18

shared_dotnet_count="$(/usr/share/dotnet/dotnet --list-sdks | wc -l | tr -d ' ')"
test "${shared_dotnet_count}" -ge 4

verify_toolchain() {
  selector="$1"
  executable="$2"
  shift 2
  printf 'Verifying %-22s ' "${selector}"
  MISE_OFFLINE=1 mise exec "${selector}" -- "${executable}" "$@"
}

for selector in node@18 node@20 node@22 node@24; do
  verify_toolchain "${selector}" node --version
done
for selector in python@3.10 python@3.11 python@3.12 python@3.13 python@3.14; do
  verify_toolchain "${selector}" python --version
done
for selector in java@temurin-8 java@temurin-11 java@temurin-17 java@temurin-21 java@temurin-25; do
  verify_toolchain "${selector}" java -version
done
for selector in go@1.22 go@1.23 go@1.24 go@1.25; do
  verify_toolchain "${selector}" go version
done
for major in 6 8 9 10; do
  printf 'Verifying %-22s ' "dotnet@${major}"
  version="$("/opt/dotnet/${major}/dotnet" --version)"
  echo "${version}"
  case "${version}" in
    "${major}."*) ;;
    *) echo "Expected .NET ${major}.x, got ${version}" >&2; exit 1 ;;
  esac
done
verify_toolchain rust@stable rustc --version

echo "Multi-version toolchains and dependency caches verified."
