#!/usr/bin/env bash
# Resolve only the configuration activated on this machine by Home Manager.
set -euo pipefail
repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$repo/scripts/check-target.sh"
local_target() {
  local marker=${1:-$HOME/.config/dotnix/target} store=${2:-/nix/store} resolved target
  [[ -L $marker ]] || { echo 'Local dotnix target unavailable; apply hs for this machine first.' >&2; return 2; }
  resolved=$(realpath "$marker") || return 2
  store=$(realpath "$store") || return 2
  [[ $resolved == "$store/"* ]] || { echo 'Local dotnix target is not Home Manager-owned.' >&2; return 2; }
  target=$(cat "$marker")
  case "$target" in macbook|work|mini|linux-hm|nixos) ;; *) echo 'Unknown local dotnix target.' >&2; return 2 ;; esac
  check_target "$target" || return
  printf '%s\n' "$target"
}
if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  [[ $# == 0 ]] || { echo 'Local target takes no arguments.' >&2; exit 2; }
  local_target
fi
