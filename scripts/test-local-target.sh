#!/usr/bin/env bash
# Synthetic marker and platform checks; no activation or Nix build.
set -euo pipefail
repo=$(cd "$(dirname "$0")/.." && pwd)
source "$repo/scripts/local-target.sh"
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/store" "$tmp/home/.config/dotnix" "$tmp/mock"
cat > "$tmp/mock/uname" <<'MOCK'
#!/bin/sh
case "$1" in -s) echo Darwin;; -m) echo arm64;; esac
MOCK
cat > "$tmp/mock/id" <<'MOCK'
#!/bin/sh
case "$1" in -un) echo waqas;; -u) echo 501;; esac
MOCK
chmod +x "$tmp/mock/"*
marker="$tmp/home/.config/dotnix/target"
mock_path="$tmp/mock:/usr/bin:/bin"
if (HOME="$tmp/home" PATH="$mock_path" local_target "$marker" "$tmp/store") >/dev/null 2>&1; then
  echo 'FAIL: missing local marker accepted' >&2; exit 1
fi
printf 'macbook\n' > "$tmp/store/target"
ln -s "$tmp/store/target" "$marker"
[[ $(HOME="$tmp/home" PATH="$mock_path" local_target "$marker" "$tmp/store") == macbook ]]
printf 'mini\n' > "$tmp/store/target"
[[ $(HOME="$tmp/home" PATH="$mock_path" local_target "$marker" "$tmp/store") == mini ]]
rm "$marker"
printf 'mini\n' > "$marker"
if (HOME="$tmp/home" PATH="$mock_path" local_target "$marker" "$tmp/store") >/dev/null 2>&1; then
  echo 'FAIL: unmanaged marker accepted' >&2; exit 1
fi
rm "$marker"
printf 'work\n' > "$tmp/store/target"
ln -s "$tmp/store/target" "$marker"
if (HOME="$tmp/home" PATH="$mock_path" local_target "$marker" "$tmp/store") >/dev/null 2>&1; then
  echo 'FAIL: marker with wrong local user accepted' >&2; exit 1
fi
printf 'unknown\n' > "$tmp/store/target"
if (HOME="$tmp/home" PATH="$mock_path" local_target "$marker" "$tmp/store") >/dev/null 2>&1; then
  echo 'FAIL: unknown local target accepted' >&2; exit 1
fi
if HOME="$tmp/home" PATH="$mock_path" bash "$repo/scripts/local-target.sh" mini >/dev/null 2>&1; then
  echo 'FAIL: public target override accepted' >&2; exit 1
fi
echo 'PASS: local marker is managed, valid, and matches platform/user'
