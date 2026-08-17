#!/usr/bin/env bash
set -euo pipefail

lock_file="${1:-/opt/gitea-runner-offline/actions.lock}"
cache_root="${2:-/root/.cache/act}"

test -f "${lock_file}"
mkdir -p "${cache_root}"

while IFS='|' read -r cache_name repository commit friendly_ref; do
  case "${cache_name}" in
    ''|'#'*) continue ;;
  esac

  if ! printf '%s' "${commit}" | grep -Eq '^[0-9a-f]{40}$'; then
    echo "Invalid commit SHA for ${cache_name}: ${commit}" >&2
    exit 1
  fi

  destination="${cache_root}/${cache_name}"
  rm -rf "${destination}"
  git init --quiet "${destination}"
  git -C "${destination}" remote add origin "${repository}"
  git -C "${destination}" fetch --quiet --depth 1 origin "${commit}"
  git -C "${destination}" checkout --quiet --detach FETCH_HEAD
  git -C "${destination}" config gc.auto 0
  printf '%s\n' "${repository}|${commit}|${friendly_ref}" >"${destination}/.offline-source"
done <"${lock_file}"

chmod -R a+rX "${cache_root}"
