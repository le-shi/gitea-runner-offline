#!/usr/bin/env bash
set -euo pipefail

lock_file="${1:-/opt/gitea-runner-offline/actions.lock}"
cache_root="${2:-/root/.cache/act}"
first_action="${3:-1}"
last_action="${4:-999999}"

test -f "${lock_file}"
mkdir -p "${cache_root}"

retry() {
  attempt=1
  while ! "$@"; do
    if [ "${attempt}" -ge 5 ]; then return 1; fi
    sleep "$((attempt * 5))"
    attempt="$((attempt + 1))"
  done
}

action_index=0
while IFS='|' read -r cache_name repository commit friendly_ref runtime_cache_key; do
  case "${cache_name}" in
    ''|'#'*) continue ;;
  esac

  action_index="$((action_index + 1))"
  if [ "${action_index}" -lt "${first_action}" ] || [ "${action_index}" -gt "${last_action}" ]; then
    continue
  fi

  if ! printf '%s' "${commit}" | grep -Eq '^[0-9a-f]{40}$'; then
    echo "Invalid commit SHA for ${cache_name}: ${commit}" >&2
    exit 1
  fi

  destination="${cache_root}/${cache_name}"
  rm -rf "${destination}"
  git init --quiet "${destination}"
  git -C "${destination}" remote add origin "${repository}"
  retry git -C "${destination}" fetch --quiet --depth 1 origin "${commit}"
  git -C "${destination}" checkout --quiet --detach FETCH_HEAD
  git -C "${destination}" config gc.auto 0
  printf '%s\n' "${repository}|${commit}|${friendly_ref}" >"${destination}/.offline-source"

  # act's offline ActionCache opens a bare repository named from owner/repo.
  # Keep this alongside the worktree used by direct verification scripts.
  repository_path="${repository%.git}"
  repository_path="${repository_path#*://}"
  repository_path="${repository_path#*/}"
  cache_key="${runtime_cache_key:-$(printf '%s' "${repository_path}" | sed 's|[^A-Za-z0-9_.-]|-|g')}"
  bare_destination="${cache_root}/${cache_key}.git"
  requested_ref="${cache_name##*@}"
  if [ ! -d "${bare_destination}" ]; then
    git init --quiet --bare "${bare_destination}"
    git --git-dir="${bare_destination}" remote add origin "${repository}"
  fi
  retry git --git-dir="${bare_destination}" fetch --quiet --depth 1 origin "${commit}"
  git --git-dir="${bare_destination}" update-ref "refs/tags/${requested_ref}" "${commit}"
  git --git-dir="${bare_destination}" update-ref "refs/tags/${friendly_ref}" "${commit}"
done <"${lock_file}"

chmod -R a+rX "${cache_root}"
