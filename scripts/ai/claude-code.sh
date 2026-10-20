#!/usr/bin/env bash
# https://code.claude.com/docs/en/setup - native production channel.
set -euo pipefail
source "$(dirname "$0")/common.sh"
action=${1:-}; [[ $# == 1 ]] || die 'usage: claude-code.sh install|update'; guard_local_ai
root="$HOME/.local/share/claude/versions"
verify() {
  local launcher=$1 version platform base temp fingerprint expected actual
  need gpg; need jq
  version=$("$launcher" --version | sed -nE 's/^([0-9]+\.[0-9]+\.[0-9]+) \(Claude Code\)$/\1/p')
  [[ -n $version ]] || die 'unexpected Claude Code version'
  platform=linux-arm64; [[ $(uname -s) != Darwin ]] || platform=darwin-arm64
  base="https://downloads.claude.ai/claude-code-releases/$version"
  temp=$(mktemp -d); trap 'rm -rf "$temp" "${installer_temp:-}"' EXIT
  curl -fsS --proto '=https' --output "$temp/key.asc" https://downloads.claude.ai/keys/claude-code.asc
  curl -fsS --proto '=https' --output "$temp/manifest.json" "$base/manifest.json"
  curl -fsS --proto '=https' --output "$temp/manifest.json.sig" "$base/manifest.json.sig"
  mkdir -m 700 "$temp/gnupg"
  fingerprint=$(gpg --homedir "$temp/gnupg" --show-keys --with-colons "$temp/key.asc" | awk -F: '$1=="fpr" {print $10; exit}')
  [[ $fingerprint == 31DDDE24DDFAB679F42D7BD2BAA929FF1A7ECACE ]] || die 'Anthropic signing fingerprint mismatch'
  gpg --homedir "$temp/gnupg" --quiet --import "$temp/key.asc"
  gpg --homedir "$temp/gnupg" --verify "$temp/manifest.json.sig" "$temp/manifest.json" >/dev/null 2>&1 || die 'Anthropic manifest signature failed'
  expected=$(jq -er --arg p "$platform" '.platforms[$p].checksum' "$temp/manifest.json")
  actual=$(shasum -a 256 "$(realpath "$launcher")" | awk '{print $1}')
  [[ $actual == "$expected" ]] || die 'Claude binary checksum differs from signed manifest'
  [[ $(uname -s) != Darwin ]] || codesign --verify "$(realpath "$launcher")"
  rm -rf "$temp"
  if [[ -n ${installer_temp:-} ]]; then trap 'rm -rf "$installer_temp"' EXIT; else trap - EXIT; fi
}
case "$action" in
  install)
    if launcher=$(native_launcher claude "$root"); then echo 'Claude Code already uses its native owner.'; exit 0; fi
    need gpg
    installer_temp=$(mktemp -d); trap 'rm -rf "$installer_temp"' EXIT
    stage_script https://claude.ai/install.sh https://claude.ai/install.sh "$installer_temp/install.sh"
    bash "$installer_temp/install.sh" latest
    launcher=$(native_launcher claude "$root") || die 'Claude native launcher missing after install'
    verify "$launcher"
    rm -rf "$installer_temp"; trap - EXIT
    ;;
  update)
    launcher=$(native_launcher claude "$root") || die 'install Claude Code first'
    "$launcher" update
    verify "$launcher"
    ;;
  *) die 'usage: claude-code.sh install|update' ;;
esac
