#!/usr/bin/env bash
# Public mise build/doctor entry point. No target selection or activation.
set -euo pipefail
repo=$(cd "$(dirname "$0")/.." && pwd)
action=${1:-}; shift || true
[[ $# == 0 ]] || { echo 'Local Nix task takes no target or extra arguments.' >&2; exit 2; }
case "$action" in build|doctor) ;; *) echo 'Usage: local-nix.sh build|doctor' >&2; exit 2 ;; esac
target=$(bash "$repo/scripts/local-target.sh")
cd "$repo"
if [[ $action == doctor ]]; then
  case "$target" in
    macbook|work|mini) exec bash scripts/dotnix-doctor.sh --machine "$target" ;;
  esac
fi
case "$target" in
  macbook|work|mini) ref=".#darwinConfigurations.$target.system" ;;
  linux-hm) ref='.#homeConfigurations."waqas.ahmed".activationPackage' ;;
  nixos) ref='.#nixosConfigurations.nixos.config.system.build.toplevel' ;;
esac
if [[ $action == build ]]; then
  exec nix build --no-link --no-write-lock-file --no-update-lock-file "$ref"
fi
mise doctor
exec nix eval --no-write-lock-file --no-update-lock-file --raw "$ref.drvPath"
