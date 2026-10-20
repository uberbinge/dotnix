#!/usr/bin/env bash
# https://github.com/AltanS/collie - standalone release archive and updater.
set -euo pipefail
source "$(dirname "$0")/common.sh"
action=${1:-}; permission=${2:-}; guard_local_ai
[[ $# -le 2 ]] || die 'usage: collie.sh install|update [--allow-service-restart]'
root="$HOME/.local/share/collie"
case "$action" in
  install)
    [[ -z $permission ]] || die 'install takes no additional arguments'
    if native_launcher collie "$root" >/dev/null; then echo 'Collie already installed; no service started.'; exit 0; fi
    temp=$(mktemp -d); trap 'rm -rf "$temp"' EXIT
    stage_script https://colliepwa.dev/install.sh https://colliepwa.dev/install.sh "$temp/install.sh"
    # Upstream installer checks release manifest and archive SHA-256.
    COLLIE_UPDATE_REPO=AltanS/collie COLLIE_DIR="$root" COLLIE_TAG= sh "$temp/install.sh"
    native_launcher collie "$root" >/dev/null || die 'Collie standalone launcher missing after install'
    echo 'Collie installed; listener, pairing, and service startup remain disabled.'
    ;;
  update)
    [[ $permission == --allow-service-restart ]] || die 'Collie update may restart its bridge; pass --allow-service-restart explicitly'
    launcher=$(native_launcher collie "$root") || die 'install Collie first'
    COLLIE_UPDATE_REPO=AltanS/collie COLLIE_DIR="$root" COLLIE_TAG= "$launcher" update
    ;;
  *) die 'usage: collie.sh install|update [--allow-service-restart]' ;;
esac
