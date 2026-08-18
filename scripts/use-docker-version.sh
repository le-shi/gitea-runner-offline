#!/usr/bin/env bash
set -euo pipefail

requested="${1:?usage: use-docker-version <27|28|29|exact-version>}"

if [ -x "/opt/docker/${requested}/bin/docker" ]; then
  selected="${requested}"
else
  matches=(/opt/docker/"${requested}".*/bin/docker)
  if [ "${#matches[@]}" -ne 1 ] || [ ! -x "${matches[0]}" ]; then
    echo "Docker CLI version '${requested}' is not installed." >&2
    exit 1
  fi
  selected="$(basename "$(dirname "$(dirname "${matches[0]}")")")"
fi

ln -sfn "/opt/docker/${selected}/bin/docker" /usr/local/bin/docker
docker --version
