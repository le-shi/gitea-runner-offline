#!/usr/bin/env bash
set -euo pipefail

work_root="$(mktemp -d)"
trap 'rm -rf "${work_root}"' EXIT

# npm must install a real package from the bundled tarball repository.
mkdir -p "${work_root}/npm"
(cd /opt/offline-cache/npm-packages && sha256sum --check SHA256SUMS)
typescript_tarball="/opt/offline-cache/npm-packages/typescript-7.0.2.tgz"
test -f "${typescript_tarball}"
MISE_OFFLINE=1 mise exec node@24.19.0 -- npm install --offline --ignore-scripts \
  --prefix "${work_root}/npm" "${typescript_tarball}"
test -x "${work_root}/npm/node_modules/.bin/tsc"
test "$(MISE_OFFLINE=1 mise exec node@24.19.0 -- node -p "require('${work_root}/npm/node_modules/typescript/package.json').version")" = 7.0.2

# pip must resolve and copy wheels without consulting an index.
/opt/venvs/python-tools/bin/pip download --no-index \
  --find-links /opt/offline-cache/pip-wheelhouse --dest "${work_root}/pip" requests==2.34.2
test -n "$(find "${work_root}/pip" -name 'requests-2.34.2-*.whl' -print -quit)"

# Maven performs a genuine offline resolution against the bundled repository.
mvn --offline --batch-mode --no-transfer-progress \
  -Dmaven.repo.local=/opt/offline-cache/maven \
  org.apache.maven.plugins:maven-dependency-plugin:3.7.0:get \
  -Dartifact=com.google.guava:guava:33.4.8-jre

# Go and Cargo caches must contain source/module data as well as installed CLIs.
test -n "$(find /opt/offline-cache/go/pkg/mod/cache/download -name '*.zip' -print -quit)"
test -n "$(find /opt/offline-cache/cargo/registry/cache -name '*.crate' -print -quit)"
GOPROXY=off go version -m /opt/offline-cache/go/bin/goimports >/dev/null
test -f /opt/offline-cache/go/pkg/mod/cache/download/golang.org/x/tools/@v/v0.49.0.mod
CARGO_NET_OFFLINE=true cargo install --list | grep -q '^cargo-audit v0.22.2:'

# RubyGems must reinstall a cached gem archive without contacting rubygems.org.
rake_gem="/opt/offline-cache/ruby/gems/cache/rake-13.4.2.gem"
test -f "${rake_gem}"
MISE_OFFLINE=1 mise exec ruby@3.4.10 -- gem install --local --no-document \
  --install-dir "${work_root}/ruby" "${rake_gem}"
test -x "${work_root}/ruby/bin/rake"

echo "npm, pip, Maven, Go, Cargo and RubyGems caches passed network-disabled checks."
