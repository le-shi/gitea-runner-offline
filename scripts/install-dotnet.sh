#!/usr/bin/env bash
set -euo pipefail

install_script_commit="03c981b3ae8261cb0a48b07ac884ce0031af384c"
install_script="$(mktemp)"
trap 'rm -f "${install_script}"' EXIT

curl --fail --location --retry 5 \
  "https://raw.githubusercontent.com/dotnet/install-scripts/${install_script_commit}/src/dotnet-install.sh" \
  --output "${install_script}"
chmod 0755 "${install_script}"

case "${TARGETARCH:-}" in
  amd64) dotnet_arch=x64 ;;
  arm64) dotnet_arch=arm64 ;;
  *) echo "Unsupported .NET architecture: ${TARGETARCH:-unset}" >&2; exit 1 ;;
esac

mkdir -p /opt/dotnet
for channel in 6.0 8.0 9.0 10.0; do
  install_dir="/opt/dotnet/${channel%%.*}"
  "${install_script}" \
    --channel "${channel}" \
    --quality GA \
    --architecture "${dotnet_arch}" \
    --install-dir "${install_dir}" \
    --no-path
  ln -s "${install_dir}/dotnet" "/usr/local/bin/dotnet${channel%%.*}"
done

ln -s /opt/dotnet/10/dotnet /usr/local/bin/dotnet

for major in 6 8 9 10; do
  version="$("/opt/dotnet/${major}/dotnet" --version)"
  case "${version}" in
    "${major}."*) ;;
    *) echo "Expected .NET ${major}.x, got ${version}" >&2; exit 1 ;;
  esac
done
