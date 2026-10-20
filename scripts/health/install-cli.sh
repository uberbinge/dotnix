#!/usr/bin/env bash
set -euo pipefail

# Build only Go source from the local checkout. Never use the health-export
# repository as a Nix input: it currently tracks private data files.
source_dir="${HEALTH_EXPORT_SERVER_DIR:-$HOME/dev/health-export/health-server}"
if [[ ! -f "$source_dir/go.mod" || ! -f "$source_dir/main.go" ]]; then
  printf 'health-server source not found at %s\n' "$source_dir" >&2
  exit 1
fi
if ! command -v go >/dev/null 2>&1; then
  printf 'Go is unavailable; run mise run runtimes:install first.\n' >&2
  exit 1
fi

install_dir="$HOME/.local/bin"
mkdir -p "$install_dir"
temporary_binary="$(mktemp "$install_dir/.hk-cli.XXXXXXXX")"
trap 'rm -f "$temporary_binary"' EXIT

(
  cd "$source_dir"
  GOTOOLCHAIN=local go build -trimpath -o "$temporary_binary" .
)
chmod 0755 "$temporary_binary"
mv -f "$temporary_binary" "$install_dir/hk-cli"
trap - EXIT
printf 'Installed %s\n' "$install_dir/hk-cli"
