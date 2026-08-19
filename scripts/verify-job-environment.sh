#!/usr/bin/env bash
set -euo pipefail

required_environment="GITHUB_WORKSPACE GITHUB_ENV GITHUB_OUTPUT GITHUB_PATH RUNNER_TEMP RUNNER_TOOL_CACHE"
for name in ${required_environment}; do
  value="${!name-}"
  test -n "${value}" || {
    echo "Missing Job environment variable: ${name}" >&2
    exit 1
  }
done

test -d "${GITHUB_WORKSPACE}"
test -w "${GITHUB_WORKSPACE}"
test -d "${RUNNER_TEMP}"
test -w "${RUNNER_TEMP}"
test -d "${RUNNER_TOOL_CACHE}"
test -w "$(dirname "${GITHUB_ENV}")"
test -w "$(dirname "${GITHUB_OUTPUT}")"
test -w "$(dirname "${GITHUB_PATH}")"

for directory in /github/home /github/workflow /github/file_commands /opt/acttoolcache; do
  test -d "${directory}"
done

git config --system --get-all safe.directory | grep -qxF '*'
show-offline-capabilities >/dev/null

mise exec node@20.20.2 -- node --version
mise exec node@24.19.0 -- node --version
mise exec python@3.12.14 -- python --version
mise exec go@1.25.13 -- go version
mise exec java@temurin-21.0.12+8.0.LTS -- java -version
mise exec rust@1.97.1 -- rustc --version

if test -S /var/run/docker.sock; then
  docker29 version --format '{{.Client.Version}}'
  docker29 buildx version
  docker29 compose version
else
  echo "Docker socket is not mounted in this Job Container." >&2
  exit 1
fi

printf '%s\n' 'OFFLINE_JOB_ENV=verified' >>"${GITHUB_ENV}"
printf '%s\n' 'offline_job_environment=verified' >>"${GITHUB_OUTPUT}"

echo "Runner-to-Job-Container environment verified."
