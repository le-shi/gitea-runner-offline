#!/usr/bin/env bash
set -euo pipefail

version="${1:?Composer version is required}"
expected_sha256="${2:?Composer SHA-256 is required}"
download_url="https://github.com/composer/composer/releases/download/${version}/composer.phar"
destination=/usr/local/bin/composer

curl --fail --location --retry 5 --retry-all-errors \
  "${download_url}" --output "${destination}"
echo "${expected_sha256}  ${destination}" | sha256sum --check --strict
chmod 0755 "${destination}"
mise exec php@8.4 -- composer --version
