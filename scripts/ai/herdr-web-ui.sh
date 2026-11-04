#!/usr/bin/env bash
# https://github.com/devswha/herdr-web-ui ; link disabled, never serve/pair.
set -euo pipefail
source "$(dirname "$0")/common.sh"
action=${1:-}; [[ $# == 1 ]] || die 'usage: herdr-web-ui.sh install|update'; guard_local_mac
[[ $action == install || $action == update ]] || die 'usage: herdr-web-ui.sh install|update'
for tool in herdr git bun node mise jq; do need "$tool"; done
[[ $(command -v herdr) == /opt/homebrew/bin/herdr ]] || die 'Herdr must have its Brew PATH owner'
for tool in bun node; do
  actual=$(realpath "$(mise which "$tool")")
  mise_root=$(realpath "$HOME/.local/share/mise/installs/$tool")
  [[ $actual == "$mise_root/"* && $(realpath "$(command -v "$tool")") == "$actual" ]] || die "$tool must be from mise"
done
node_version=$(node --version); version_ge "${node_version#v}" 18.0.0 || die 'Herdr web UI requires Node 18+'
version_ge "$(bun --version)" 1.4.0 || die 'Herdr web UI requires Bun 1.4+'
herdr_version=$(herdr --version | sed -nE 's/[^0-9]*([0-9]+\.[0-9]+\.[0-9]+).*/\1/p')
version_ge "$herdr_version" 0.9.0 || die 'Herdr web UI requires Herdr 0.9+'
plugin_id=devswha.herdr-web-ui
plugins=$(herdr plugin list --json) || die 'cannot read Herdr plugin inventory'
jq -e '.result.plugins | type == "array"' <<< "$plugins" >/dev/null || die 'invalid Herdr plugin inventory'
plugin=$(jq -cr --arg id "$plugin_id" '.result.plugins[] | select(.plugin_id==$id)' <<< "$plugins")
if [[ -n $plugin ]]; then
  source_kind=$(jq -r '.source.kind' <<< "$plugin")
  case $source_kind in
    github) [[ $(jq -r '.source.owner + "/" + .source.repo' <<< "$plugin") == devswha/herdr-web-ui ]] || die 'plugin source is not selected upstream' ;;
    local) [[ $(realpath "$(jq -r '.plugin_root' <<< "$plugin")") == "$HOME/.local/share/dotnix/herdr-web-ui" ]] || die 'plugin linked from another checkout' ;;
    *) die 'unrecognized Herdr plugin source' ;;
  esac
  if [[ $action == install ]]; then
    echo "Herdr web UI already installed from the verified source (enabled=$(jq -r '.enabled' <<< "$plugin")); existing service state unchanged."
    exit 0
  fi
  [[ $(jq -r '.enabled' <<< "$plugin") == false ]] || die 'disable and stop the web UI before scripted changes'
elif [[ $action == update ]]; then die 'install Herdr web UI first'
fi
dest="$HOME/.local/share/dotnix/herdr-web-ui"
tag=$(latest_tag devswha/herdr-web-ui)
if [[ -e $dest ]]; then
  [[ -d $dest/.git && $(git -C "$dest" remote get-url origin) == https://github.com/devswha/herdr-web-ui.git ]] || die 'untrusted Herdr web UI checkout'
  [[ -z $(git -C "$dest" status --porcelain) ]] || die 'Herdr web UI checkout has local changes'
  old=$(git -C "$dest" rev-parse HEAD)
  git -C "$dest" fetch --depth 1 origin "$tag"
  git -C "$dest" checkout --detach FETCH_HEAD
else
  mkdir -p "$(dirname "$dest")"
  git clone --depth 1 --branch "$tag" https://github.com/devswha/herdr-web-ui.git "$dest"
  old=
fi
if ! (cd "$dest" && bun install --frozen-lockfile --ignore-scripts && bun run build && herdr plugin link "$dest" --disabled); then
  [[ -z $old ]] || git -C "$dest" checkout --detach "$old"
  die 'Herdr web UI build/link failed; prior checkout restored when available'
fi
echo 'Herdr web UI linked disabled; no listener, pairing, or remote access started.'
