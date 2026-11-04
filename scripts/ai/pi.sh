#!/usr/bin/env bash
# https://pi.dev/docs/latest/quickstart - official npm alternative under mise Node.
set -euo pipefail
source "$(dirname "$0")/common.sh"
action=${1:-}; [[ $# == 1 ]] || die 'usage: pi.sh install|update'; guard_local_ai
[[ $action == install || $action == update ]] || die 'usage: pi.sh install|update'
for tool in mise node npm jq; do need "$tool"; done
node_path=$(realpath "$(mise which node)")
mise_node_root=$(realpath "$HOME/.local/share/mise/installs/node")
[[ $node_path == "$mise_node_root/"* && $(realpath "$(command -v node)") == "$node_path" ]] || die 'Pi requires the selected mise Node on PATH'
node_version=$(node --version); node_version=${node_version#v}
version_ge "$node_version" 22.19.0 || die 'Pi requires Node 22.19 or newer'
prefix=$(realpath "$(npm prefix -g)")
[[ $node_path == "$(realpath "$prefix/bin/node")" && $(realpath "$(command -v npm)") == "$(realpath "$prefix/bin/npm")" ]] || die 'npm global prefix must belong to mise Node'
[[ $(npm config get registry) == https://registry.npmjs.org/ ]] || die 'npm registry differs from official registry'
package=@earendil-works/pi-coding-agent
package_dir="$prefix/lib/node_modules/$package"
pi_path="$prefix/bin/pi"
if [[ -e $pi_path || -L $pi_path || -n $(command -v pi 2>/dev/null || true) ]]; then
  [[ -L $pi_path && -e $pi_path && $(realpath "$pi_path") == "$package_dir/"* && $(realpath "$(command -v pi)") == "$(realpath "$pi_path")" ]] || die 'Pi has another PATH/package owner'
  paths=$(type -a -p pi 2>/dev/null | sort -u)
  [[ $(printf '%s\n' "$paths" | wc -l | tr -d ' ') == 1 && $(realpath "$paths") == "$(realpath "$pi_path")" ]] || die 'Pi has duplicate PATH owners'
  current=$(jq -er --arg p "$package" 'select(.name==$p) | .version' "$package_dir/package.json") || die 'Pi package metadata invalid'
  [[ $current =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die 'Pi package version is not production semver'
  if [[ $action == install ]]; then echo 'Pi already installed under mise Node.'; exit 0; fi
else
  current=
fi
latest=$(npm view "$package" version)
[[ $latest =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die 'npm did not report a production version'
if [[ -n $current ]] && version_ge "$current" "$latest"; then echo "Pi $current is at or ahead of production $latest"; exit 0; fi
npm install -g --ignore-scripts --registry https://registry.npmjs.org/ "$package@$latest"
[[ -L $pi_path && -e $pi_path && $(realpath "$pi_path") == "$package_dir/"* ]] || die 'Pi npm launcher ownership check failed'
[[ $(jq -er '.version' "$package_dir/package.json") == "$latest" ]] || die 'Pi installed version differs from registry result'
