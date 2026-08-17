#!/usr/bin/env sh
set -eu

required_commands="bash curl git git-lfs jq ssh rsync tar unzip zip xz"
for command_name in ${required_commands}; do
  command -v "${command_name}" >/dev/null 2>&1 || {
    echo "Missing command: ${command_name}" >&2
    exit 1
  }
done

lock_file=/opt/gitea-runner-offline/actions.lock
cache_root=/root/.cache/act
test -s "${lock_file}"

expected_count="$(grep -Ev '^[[:space:]]*(#|$)' "${lock_file}" | wc -l | tr -d ' ')"
actual_count="$(find "${cache_root}" -mindepth 2 -maxdepth 2 -name .offline-source | wc -l | tr -d ' ')"

if [ "${expected_count}" != "${actual_count}" ]; then
  echo "Action cache mismatch: expected ${expected_count}, found ${actual_count}" >&2
  exit 1
fi

echo "Offline runner image verified: ${actual_count} Actions and required tools are present."
