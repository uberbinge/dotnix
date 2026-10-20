#!/usr/bin/env bash
# Guard commands that change a selected host. Sourceable for fixture tests.
set -euo pipefail
check_target() {
  local target=${1:-} system arch user expected_system expected_arch expected_user
  case "$target" in
    macbook|mini) expected_system=Darwin; expected_arch=arm64; expected_user=waqas ;;
    work) expected_system=Darwin; expected_arch=arm64; expected_user=waqas.ahmed ;;
    linux-hm|nixos) expected_system=Linux; expected_arch=aarch64; expected_user=waqas.ahmed ;;
    *) echo "Unknown target: $target" >&2; return 2 ;;
  esac
  system=$(uname -s); arch=$(uname -m); user=$(id -un)
  if [[ $system != "$expected_system" || $arch != "$expected_arch" || $user != "$expected_user" || $(id -u) == 0 ]]; then
    echo "Target $target requires $expected_user on $expected_system/$expected_arch as a regular user; found $user on $system/$arch" >&2
    return 3
  fi
}
if [[ ${BASH_SOURCE[0]} == "$0" ]]; then check_target "${1:-}"; fi
