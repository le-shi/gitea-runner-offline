#!/usr/bin/env bash
set -euo pipefail

patch_record=/opt/gitea-runner-offline/offline-action-patches.txt
: > "${patch_record}"

for action_major in v3 v4 v5; do
  action_root="/root/.cache/act/actions-setup-dotnet@${action_major}"
  install_script="${action_root}/externals/install-dotnet.sh"
  upstream_script="${install_script}.upstream"

  test -f "${install_script}"
  mv "${install_script}" "${upstream_script}"

  cat > "${install_script}" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

install_dir="${DOTNET_INSTALL_DIR:-/usr/share/dotnet}"
requested_version=""
runtime_kind=""

while (($#)); do
  case "$1" in
    --version)
      requested_version="${2:-}"
      shift 2
      ;;
    --runtime)
      runtime_kind="${2:-}"
      shift 2
      ;;
    --channel|--quality|--architecture|--install-dir)
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

if [[ "${runtime_kind}" == dotnet ]]; then
  requested_version="$("${install_dir}/dotnet" --list-runtimes \
    | awk '$1 == "Microsoft.NETCore.App" {print $2}' \
    | sort -V \
    | tail -n 1)"
  test -n "${requested_version}"
  echo "dotnet-install: .NET Runtime with version '${requested_version}' is already installed."
  exit 0
fi

if [[ -n "${requested_version}" && -d "${install_dir}/sdk/${requested_version}" ]]; then
  echo "dotnet-install: .NET SDK with version '${requested_version}' is already installed."
  exit 0
fi

echo "Offline setup-dotnet cannot install '${requested_version:-a channel or floating version}'." >&2
echo "Use an exact SDK version already present under ${install_dir}/sdk." >&2
exit 1
EOF

  chmod 0755 "${install_script}"
  printf '%s\n' \
    "actions/setup-dotnet@${action_major}: externals/install-dotnet.sh wrapped for exact-version offline reuse; original retained as install-dotnet.sh.upstream" \
    >> "${patch_record}"
done
