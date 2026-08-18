#!/usr/bin/env bash
set -euo pipefail

export MISE_CONFIG_FILE=/opt/gitea-runner-offline/mise.toml
toolcache="${RUNNER_TOOL_CACHE:-/opt/hostedtoolcache}"

case "${TARGETARCH:-}" in
  amd64) cache_arch=x64 ;;
  arm64) cache_arch=arm64 ;;
  *) echo "Unsupported tool-cache architecture: ${TARGETARCH:-unset}" >&2; exit 1 ;;
esac

cache_mise_tool() {
  cache_name="$1"
  selector="$2"
  version="$3"
  source_dir="$(mise where "${selector}")"
  destination="${toolcache}/${cache_name}/${version}/${cache_arch}"

  mkdir -p "$(dirname "${destination}")"
  ln -s "${source_dir}" "${destination}"
  touch "${destination}.complete"
}

for version in 18.20.8 20.20.2 22.23.2 24.19.0; do
  resolved_version="$(mise exec "node@${version}" -- node -p 'process.versions.node')"
  cache_mise_tool node "node@${version}" "${resolved_version}"
done

for version in 3.10.21 3.11.16 3.12.14 3.13.15 3.14.7; do
  resolved_version="$(mise exec "python@${version}" -- python -c 'import platform; print(platform.python_version())')"
  cache_mise_tool Python "python@${version}" "${resolved_version}"
done

for version in 1.22.12 1.23.12 1.24.13 1.25.13; do
  resolved_version="$(mise exec "go@${version}" -- go env GOVERSION)"
  cache_mise_tool go "go@${version}" "${resolved_version#go}"
done

for version in 8.0.502+7 11.0.32+9 17.0.20+8 21.0.12+8.0.LTS 25.0.4+7.0.LTS; do
  selector="java@temurin-${version}"
  raw_version="$(mise exec "${selector}" -- java -XshowSettings:properties -version 2>&1 | awk -F'= ' '/^[[:space:]]*java.version = / {print $2; exit}')"
  case "${raw_version}" in
    1.8.0_*) version="8.0.${raw_version#1.8.0_}" ;;
    *) version="${raw_version%%+*}" ;;
  esac
  cache_mise_tool Java_Temurin-Hotspot_jdk "${selector}" "${version}"
done

find "${toolcache}" -type l -print | sort > /opt/gitea-runner-offline/toolcache.links.txt
