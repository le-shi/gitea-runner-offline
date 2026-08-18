#!/usr/bin/env bash
set -euo pipefail

seed_root="${1:-/opt/gitea-runner-offline/dependency-seeds}"
cache_root="${2:-/opt/offline-cache}"
export MISE_CONFIG_FILE=/opt/gitea-runner-offline/mise.toml
export npm_config_fetch_retries=5
export npm_config_fetch_retry_maxtimeout=120000
export CARGO_NET_RETRY=10

retry() {
  attempt=1
  while ! "$@"; do
    if [ "${attempt}" -ge 5 ]; then return 1; fi
    sleep "$((attempt * 10))"
    attempt="$((attempt + 1))"
  done
}

mkdir -p "${cache_root}/npm" "${cache_root}/pip-wheelhouse" "${cache_root}/maven" \
  "${cache_root}/go" "${cache_root}/cargo" "${cache_root}/ruby"

# Install popular JS tooling and retain npm's tarball cache for offline installs.
mapfile -t node_packages < <(grep -Ev '^[[:space:]]*(#|$)' "${seed_root}/node-packages.txt")
retry env NPM_CONFIG_CACHE="${cache_root}/npm" mise exec node@24 -- npm install --global "${node_packages[@]}"

# Use Python 3.12 for the shared automation environment and preserve wheels.
mise exec python@3.12 -- python -m venv /opt/venvs/python-tools
retry /opt/venvs/python-tools/bin/pip install --retries 10 --timeout 60 --upgrade pip setuptools wheel
retry /opt/venvs/python-tools/bin/pip download --retries 10 --timeout 60 --dest "${cache_root}/pip-wheelhouse" \
  --requirement "${seed_root}/python-requirements.txt"
/opt/venvs/python-tools/bin/pip install --no-index --find-links "${cache_root}/pip-wheelhouse" \
  --requirement "${seed_root}/python-requirements.txt"

# Populate Maven's local repository with common build/test dependencies.
export MAVEN_OPTS="-Dmaven.repo.local=${cache_root}/maven"
download_maven_artifact() {
  artifact="$1"
  attempt=1
  while ! mise exec maven@3.9 -- mvn --batch-mode --no-transfer-progress \
    -Dmaven.wagon.http.retryHandler.count=5 \
    org.apache.maven.plugins:maven-dependency-plugin:3.7.0:get -Dartifact="${artifact}"; do
    if [ "${attempt}" -ge 5 ]; then
      echo "Maven artifact download failed after ${attempt} attempts: ${artifact}" >&2
      return 1
    fi
    sleep "$((attempt * 10))"
    attempt="$((attempt + 1))"
  done
}
while IFS= read -r artifact; do
  case "${artifact}" in ''|'#'*) continue ;; esac
  download_maven_artifact "${artifact}"
done < "${seed_root}/maven-artifacts.txt"

# Compile common Go and Rust developer tools once while the image has network.
export GOPATH="${cache_root}/go"
export GOBIN="${GOPATH}/bin"
mkdir -p "${GOBIN}"
while IFS= read -r package; do
  case "${package}" in ''|'#'*) continue ;; esac
  retry mise exec go@1.25 -- go install "${package}"
  tool_name="${package%%@*}"
  tool_name="${tool_name##*/}"
  test -x "${GOBIN}/${tool_name}"
done < "${seed_root}/go-tools.txt"

export CARGO_HOME="${cache_root}/cargo"
while IFS= read -r crate; do
  case "${crate}" in ''|'#'*) continue ;; esac
  retry mise exec rust@stable -- cargo install --locked "${crate}"
done < "${seed_root}/rust-tools.txt"

# Retain downloaded gem archives so Ruby dependencies can be reinstalled
# without network access.
export GEM_HOME="${cache_root}/ruby/gems"
export GEM_SPEC_CACHE="${cache_root}/ruby/specs"
mkdir -p "${GEM_HOME}" "${GEM_SPEC_CACHE}"
while IFS= read -r gem_name; do
  case "${gem_name}" in ''|'#'*) continue ;; esac
  retry mise exec ruby@3.4 -- gem install --no-document "${gem_name}"
done < "${seed_root}/ruby-gems.txt"
