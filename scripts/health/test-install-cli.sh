#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "$0")/../.." && pwd)"
fixture="$(mktemp -d "${TMPDIR:-/tmp}/hk-cli-install-test.XXXXXXXX")"
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/home" "$fixture/payload"
printf '#!/bin/sh\nprintf "synthetic cli\\n"\n' > "$fixture/payload/hk-cli"
COPYFILE_DISABLE=1 tar --format=ustar -czf "$fixture/valid.tar.gz" -C "$fixture/payload" hk-cli
checksum="$(shasum -a 256 "$fixture/valid.tar.gz")"
checksum="${checksum%% *}"

HOME="$fixture/home" HK_CLI_ARCHIVE="$fixture/valid.tar.gz" HK_CLI_SHA256="$checksum" \
  bash "$repo_dir/scripts/health/install-cli.sh" >/dev/null
test -x "$fixture/home/.local/bin/hk-cli"
test "$(cat "$fixture/home/.local/bin/hk-cli")" = '#!/bin/sh
printf "synthetic cli\n"'

printf 'existing binary\n' > "$fixture/home/.local/bin/hk-cli"
wrong_checksum="0${checksum:1}"
if [[ "$wrong_checksum" == "$checksum" ]]; then wrong_checksum="1${checksum:1}"; fi
if HOME="$fixture/home" HK_CLI_ARCHIVE="$fixture/valid.tar.gz" \
  HK_CLI_SHA256="$wrong_checksum" bash "$repo_dir/scripts/health/install-cli.sh" >/dev/null 2>&1; then
  printf 'Installer accepted a bad checksum.\n' >&2
  exit 1
fi
test "$(cat "$fixture/home/.local/bin/hk-cli")" = 'existing binary'

printf 'extra\n' > "$fixture/payload/extra"
COPYFILE_DISABLE=1 tar --format=ustar -czf "$fixture/extra.tar.gz" -C "$fixture/payload" hk-cli extra
extra_checksum="$(shasum -a 256 "$fixture/extra.tar.gz")"
if HOME="$fixture/home" HK_CLI_ARCHIVE="$fixture/extra.tar.gz" \
  HK_CLI_SHA256="${extra_checksum%% *}" bash "$repo_dir/scripts/health/install-cli.sh" >/dev/null 2>&1; then
  printf 'Installer accepted an extra archive member.\n' >&2
  exit 1
fi
test "$(cat "$fixture/home/.local/bin/hk-cli")" = 'existing binary'

rm "$fixture/payload/hk-cli"
ln -s extra "$fixture/payload/hk-cli"
COPYFILE_DISABLE=1 tar --format=ustar -czf "$fixture/link.tar.gz" -C "$fixture/payload" hk-cli
link_checksum="$(shasum -a 256 "$fixture/link.tar.gz")"
if HOME="$fixture/home" HK_CLI_ARCHIVE="$fixture/link.tar.gz" \
  HK_CLI_SHA256="${link_checksum%% *}" bash "$repo_dir/scripts/health/install-cli.sh" >/dev/null 2>&1; then
  printf 'Installer accepted a symlink archive member.\n' >&2
  exit 1
fi
test "$(cat "$fixture/home/.local/bin/hk-cli")" = 'existing binary'

rm "$fixture/payload/hk-cli"
printf 'synthetic cli\n' > "$fixture/payload/hk-cli"
printf 'hidden metadata\n' > "$fixture/payload/._hk-cli"
COPYFILE_DISABLE=1 tar --format=ustar -czf "$fixture/metadata.tar.gz" -C "$fixture/payload" ._hk-cli hk-cli
metadata_checksum="$(shasum -a 256 "$fixture/metadata.tar.gz")"
if HOME="$fixture/home" HK_CLI_ARCHIVE="$fixture/metadata.tar.gz" \
  HK_CLI_SHA256="${metadata_checksum%% *}" bash "$repo_dir/scripts/health/install-cli.sh" >/dev/null 2>&1; then
  printf 'Installer accepted hidden archive metadata.\n' >&2
  exit 1
fi
test "$(cat "$fixture/home/.local/bin/hk-cli")" = 'existing binary'
printf 'health CLI installer fixture passed\n'
