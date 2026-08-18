#!/usr/bin/env bash
set -euo pipefail

work_root="$(mktemp -d)"
trap 'rm -rf "${work_root}"' EXIT

# npm must be able to materialize a real package tarball from its cache.
mkdir -p "${work_root}/npm"
typescript_version="$(node -p "require('/usr/local/lib/node_modules/typescript/package.json').version")"
(cd "${work_root}/npm" && npm pack --offline "typescript@${typescript_version}" >/dev/null)
test -n "$(find "${work_root}/npm" -name 'typescript-*.tgz' -print -quit)"

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
