#!/usr/bin/env bash
set -euo pipefail

export MISE_OFFLINE=1

case "$(uname -m)" in
  x86_64) runner_arch=X64 ;;
  aarch64|arm64) runner_arch=ARM64 ;;
  *) echo "Unsupported setup Action architecture: $(uname -m)" >&2; exit 1 ;;
esac

verify_root="$(mktemp -d)"
trap 'rm -rf "${verify_root}"' EXIT
mkdir -p "${verify_root}/workspace" "${verify_root}/temp"

run_action() {
  action_dir="$1"
  main_file="$2"
  shift 2
  action_log="${verify_root}/action.log"

  : > "${verify_root}/path"
  : > "${verify_root}/env"
  : > "${verify_root}/output"
  : > "${verify_root}/state"

  if ! env \
    RUNNER_OS=Linux \
    RUNNER_ARCH="${runner_arch}" \
    RUNNER_TEMP="${verify_root}/temp" \
    RUNNER_TOOL_CACHE="${RUNNER_TOOL_CACHE:-/opt/hostedtoolcache}" \
    AGENT_TOOLSDIRECTORY="${AGENT_TOOLSDIRECTORY:-/opt/hostedtoolcache}" \
    GITHUB_WORKSPACE="${verify_root}/workspace" \
    GITHUB_ACTION_PATH="${action_dir}" \
    GITHUB_PATH="${verify_root}/path" \
    GITHUB_ENV="${verify_root}/env" \
    GITHUB_OUTPUT="${verify_root}/output" \
    GITHUB_STATE="${verify_root}/state" \
    CI=true \
    "$@" \
    node "${action_dir}/${main_file}" > "${action_log}" 2>&1; then
    # Do not let an outer Actions runner interpret commands emitted by the
    # Action process that is being tested inside the container build.
    sed 's/::/--/g' "${action_log}" >&2
    return 1
  fi
}

for major in 18 20 22 24; do
  run_action /root/.cache/act/actions-setup-node@v4 dist/setup/index.js \
    "INPUT_NODE-VERSION=${major}" "INPUT_CHECK-LATEST=false" \
    "INPUT_ALWAYS-AUTH=false" "INPUT_MIRROR-ALWAYS-AUTH=false" "INPUT_CACHE="
done

for minor in 3.10 3.11 3.12 3.13 3.14; do
  run_action /root/.cache/act/actions-setup-python@v5 dist/setup/index.js \
    "INPUT_PYTHON-VERSION=${minor}" "INPUT_CHECK-LATEST=false" \
    "INPUT_ALLOW-PRERELEASES=false" "INPUT_FREETHREADED=false" \
    "INPUT_UPDATE-ENVIRONMENT=false"
done

for minor in 1.22 1.23 1.24 1.25; do
  run_action /root/.cache/act/actions-setup-go@v5 dist/setup/index.js \
    "INPUT_GO-VERSION=${minor}" "INPUT_CHECK-LATEST=false" "INPUT_CACHE=false"
done

for major in 8 11 17 21 25; do
  run_action /root/.cache/act/actions-setup-java@v4 dist/setup/index.js \
    "INPUT_DISTRIBUTION=temurin" "INPUT_JAVA-VERSION=${major}" \
    "INPUT_JAVA-PACKAGE=jdk" "INPUT_CHECK-LATEST=false" \
    "INPUT_OVERWRITE-SETTINGS=false"
done

echo "Official setup Actions resolved all 18 cached runtimes with networking disabled."
