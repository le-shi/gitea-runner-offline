#!/usr/bin/env bash
set -euo pipefail

load-offline-images

docker run --rm --network none --entrypoint buildkitd \
  moby/buildkit:buildx-stable-1 --version
docker run --rm --privileged --network none \
  tonistiigi/binfmt:qemu-v10.0.4 --version
docker run --rm --network none --entrypoint postgres \
  postgres:17-bookworm --version
docker run --rm --network none --entrypoint redis-server \
  redis:8-bookworm --version
docker run --rm --network none --entrypoint mysql \
  mysql:8.4 --version

echo "All bundled Docker images loaded and executed with networking disabled."
