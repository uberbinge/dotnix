#!/usr/bin/env bash
# Resolve only the configuration activated on this machine by Home Manager.
set -euo pipefail
local_target() {
  local marker=${1:-$HOME/.config/dotnix/target} store=${2:-/nix/store}
  local resolved target expected_system expected_arch expected_user system arch user
  [[ -L $marker ]] || { echo 'Local dotnix target unavailable; apply hs for this machine first.' >&2; return 2; }
  resolved=$(realpath "$marker") || return 2
  store=$(realpath "$store") || return 2
  [[ $resolved == "$store/"* ]] || { echo 'Local dotnix target is not Home Manager-owned.' >&2; return 2; }
  target=$(cat "$marker")
  case "$target" in
    macbook|mini) expected_system=Darwin; expected_arch=arm64; expected_user=waqas ;;
    work) expected_system=Darwin; expected_arch=arm64; expected_user=waqas.ahmed ;;
    linux-hm|nixos) expected_system=Linux; expected_arch=aarch64; expected_user=waqas.ahmed ;;
    *) echo 'Unknown local dotnix target.' >&2; return 2 ;;
  esac
  system=$(uname -s); arch=$(uname -m); user=$(id -un)
  if [[ $system != "$expected_system" || $arch != "$expected_arch" || $user != "$expected_user" || $(id -u) == 0 ]]; then
    echo "Local target $target requires $expected_user on $expected_system/$expected_arch as a regular user; found $user on $system/$arch" >&2
    return 3
  fi
  printf '%s\n' "$target"
}
if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  [[ $# == 0 ]] || { echo 'Local target takes no arguments.' >&2; exit 2; }
  local_target
fi
