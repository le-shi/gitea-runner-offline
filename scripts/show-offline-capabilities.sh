#!/usr/bin/env bash
set -euo pipefail

manifest="${1:-/opt/gitea-runner-offline/capabilities.json}"
test -s "${manifest}"

jq -r '
  "Gitea Runner Offline Capabilities",
  "=================================",
  "Architecture: \(.architecture)",
  "Runner: \(.runner)",
  "Image OS: \(.job_environment.image_os)",
  "",
  "Toolchains:",
  (.toolchains | to_entries[] | "  \(.key): \(.value | join(", "))"),
  "",
  "Docker:",
  "  default: \(.docker.default)",
  "  available: \(.docker.available_cli | map(.version) | join(", "))",
  "  buildx: \(.docker.buildx)",
  "  compose: \(.docker.compose)",
  "",
  "Offline content:",
  "  Actions: \(.actions | length)",
  "  Dependency seed files: \(.dependency_seeds | length)",
  "  Docker image archives: \(.offline_images | length)"
' "${manifest}"
