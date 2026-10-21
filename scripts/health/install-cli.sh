#!/usr/bin/env bash
set -euo pipefail

install_dir="$HOME/.local/bin"
mkdir -p "$install_dir"
temporary_binary="$(mktemp "$install_dir/.hk-cli.XXXXXXXX")"
trap 'rm -f "$temporary_binary"' EXIT

if [[ -n "${HK_CLI_ARCHIVE:-}" ]]; then
  if ! command -v python3 >/dev/null 2>&1; then
    printf 'Python 3 is required to validate the archive manifest.\n' >&2
    exit 1
  fi
  if [[ ! "${HK_CLI_SHA256:-}" =~ ^[[:xdigit:]]{64}$ ]]; then
    printf 'Set HK_CLI_SHA256 to the archive SHA-256.\n' >&2
    exit 1
  fi
  archive="$(mktemp "$install_dir/.hk-cli-archive.XXXXXXXX")"
  trap 'rm -f "$temporary_binary" "$archive"' EXIT
  case "$HK_CLI_ARCHIVE" in
    https://*) curl --fail --location --proto '=https' --tlsv1.2 --output "$archive" "$HK_CLI_ARCHIVE" ;;
    /*) cp "$HK_CLI_ARCHIVE" "$archive" ;;
    *) printf 'HK_CLI_ARCHIVE must be an HTTPS URL or absolute local path.\n' >&2; exit 1 ;;
  esac
  actual_sha="$(shasum -a 256 "$archive")"
  if [[ "${actual_sha%% *}" != "$HK_CLI_SHA256" ]]; then
    printf 'hk-cli archive SHA-256 mismatch.\n' >&2
    exit 1
  fi
  python3 - "$archive" "$temporary_binary" <<'PY'
import shutil
import sys
import tarfile

with tarfile.open(sys.argv[1], "r:gz") as artifact:
    members = artifact.getmembers()
    if len(members) != 1 or members[0].name != "hk-cli" or not members[0].isfile():
        raise SystemExit("hk-cli archive must contain only one regular hk-cli binary")
    with artifact.extractfile(members[0]) as source, open(sys.argv[2], "wb") as target:
        shutil.copyfileobj(source, target)
PY
else
  # Local fallback. Never use the repository as a Nix input: it tracks data.
  source_dir="${HEALTH_EXPORT_SERVER_DIR:-$HOME/dev/health-export/health-server}"
  if [[ ! -f "$source_dir/go.mod" || ! -f "$source_dir/main.go" ]]; then
    printf 'health-server source not found at %s; set HK_CLI_ARCHIVE and HK_CLI_SHA256 to install without a checkout.\n' "$source_dir" >&2
    exit 1
  fi
  if ! command -v go >/dev/null 2>&1; then
    printf 'Go is unavailable; run mise run runtimes:install first.\n' >&2
    exit 1
  fi
  (
    cd "$source_dir"
    GOTOOLCHAIN=local go build -trimpath -o "$temporary_binary" .
  )
fi
chmod 0755 "$temporary_binary"
mv -f "$temporary_binary" "$install_dir/hk-cli"
trap - EXIT
if [[ -n "${archive:-}" ]]; then rm -f "$archive"; fi
printf 'Installed %s\n' "$install_dir/hk-cli"
