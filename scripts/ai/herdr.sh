#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"
[[ $# == 1 && $1 == update ]] || die 'usage: herdr.sh update'
guard_local_mac
[[ $(command -v herdr || true) == /opt/homebrew/bin/herdr ]] || die 'Herdr must have its Brew PATH owner'
need brew
brew update
brew upgrade herdr
