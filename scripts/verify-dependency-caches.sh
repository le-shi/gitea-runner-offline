#!/usr/bin/env bash
set -euo pipefail

work_root="$(mktemp -d)"
trap 'rm -rf "${work_root}"' EXIT

# npm must install a real package from the bundled tarball repository.
mkdir -p "${work_root}/npm"
(cd /opt/offline-cache/npm-packages && sha256sum --check SHA256SUMS)
typescript_tarball="$(find /opt/offline-cache/npm-packages -maxdepth 1 -name 'typescript-*.tgz' -print -quit)"
test -n "${typescript_tarball}"
MISE_OFFLINE=1 mise exec node@24 -- npm install --offline --ignore-scripts \
  --prefix "${work_root}/npm" "${typescript_tarball}"
test -x "${work_root}/npm/node_modules/.bin/tsc"

# pip must resolve and copy wheels without consulting an index.
/opt/venvs/python-tools/bin/pip download --no-index \
  --find-links /opt/offline-cache/pip-wheelhouse --dest "${work_root}/pip" requests
test -n "$(find "${work_root}/pip" -name 'requests-*.whl' -print -quit)"

# Maven performs a genuine offline resolution against the bundled repository.
mvn --offline --batch-mode --no-transfer-progress \
  -Dmaven.repo.local=/opt/offline-cache/maven \
  org.apache.maven.plugins:maven-dependency-plugin:3.7.0:get \
  -Dartifact=com.google.guava:guava:33.4.8-jre

# Go and Cargo caches must contain source/module data as well as installed CLIs.
test -n "$(find /opt/offline-cache/go/pkg/mod/cache/download -name '*.zip' -print -quit)"
test -n "$(find /opt/offline-cache/cargo/registry/cache -name '*.crate' -print -quit)"
GOPROXY=off go version -m /opt/offline-cache/go/bin/goimports >/dev/null
CARGO_NET_OFFLINE=true cargo install --list | grep -q '^cargo-audit '

echo "npm, pip, Maven, Go and Cargo caches passed network-disabled checks."
