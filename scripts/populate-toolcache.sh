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

for major in 18 20 22 24; do
  version="$(mise exec "node@${major}" -- node -p 'process.versions.node')"
  cache_mise_tool node "node@${major}" "${version}"
done

for minor in 3.10 3.11 3.12 3.13 3.14; do
  version="$(mise exec "python@${minor}" -- python -c 'import platform; print(platform.python_version())')"
  cache_mise_tool Python "python@${minor}" "${version}"
done

for minor in 1.22 1.23 1.24 1.25; do
  version="$(mise exec "go@${minor}" -- go env GOVERSION)"
  cache_mise_tool go "go@${minor}" "${version#go}"
done

for major in 8 11 17 21 25; do
  selector="java@temurin-${major}"
  raw_version="$(mise exec "${selector}" -- java -XshowSettings:properties -version 2>&1 | awk -F'= ' '/^[[:space:]]*java.version = / {print $2; exit}')"
  case "${raw_version}" in
    1.8.0_*) version="8.0.${raw_version#1.8.0_}" ;;
    *) version="${raw_version%%+*}" ;;
  esac
  cache_mise_tool Java_Temurin-Hotspot_jdk "${selector}" "${version}"
done

find "${toolcache}" -type l -print | sort > /opt/gitea-runner-offline/toolcache.links.txt
