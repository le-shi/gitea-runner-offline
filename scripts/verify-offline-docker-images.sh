#!/usr/bin/env bash
set -euo pipefail

load-offline-images

docker run --rm --network none --entrypoint buildkitd \
  moby/buildkit:buildx-stable-1 --version
docker run --rm --privileged --network none \
  tonistiigi/binfmt:qemu-v10.0.4 --version

echo "BuildKit and binfmt images loaded and executed with networking disabled."
