#!/usr/bin/env bash
# https://omp.sh - official npm package under mise Bun; launcher in ~/.local/bin via bunfig globalBinDir.
set -euo pipefail
source "$(dirname "$0")/common.sh"
action=${1:-}; [[ $# == 1 ]] || die 'usage: omp.sh install|update'; guard_local_ai
[[ $action == install || $action == update ]] || die 'usage: omp.sh install|update'
for tool in mise bun jq curl; do need "$tool"; done
bun_path=$(realpath "$(mise which bun)")
mise_bun_root=$(realpath "$HOME/.local/share/mise/installs/bun")
[[ $bun_path == "$mise_bun_root/"* && $(realpath "$(command -v bun)") == "$bun_path" ]] || die 'omp requires the selected mise Bun on PATH'
version_ge "$(bun --version)" 1.4.4 || die 'omp requires Bun 1.4.4 or newer'
bin_dir=$(bun pm bin -g)
[[ $bin_dir == "$HOME/.local/bin" ]] || die 'Bun global bin must be ~/.local/bin; apply hs for .bunfig.toml'
stale="${BUN_INSTALL:-$HOME/.bun}/bin/omp"
[[ ! -e $stale && ! -L $stale ]] || die "stale launcher from an earlier bun install; remove $stale"
package=@oh-my-pi/pi-coding-agent
package_dir="${BUN_INSTALL:-$HOME/.bun}/install/global/node_modules/$package"
omp_path="$bin_dir/omp"
if [[ -e $omp_path || -L $omp_path || -n $(command -v omp 2>/dev/null || true) ]]; then
  [[ -L $omp_path && -e $omp_path && $(realpath "$omp_path") == "$(realpath "$package_dir")/"* && $(realpath "$(command -v omp)") == "$(realpath "$omp_path")" ]] || die 'omp has another PATH/package owner'
  paths=$(type -a -p omp 2>/dev/null | sort -u)
  [[ $(printf '%s\n' "$paths" | wc -l | tr -d ' ') == 1 ]] || die 'omp has duplicate PATH owners'
  current=$(jq -er --arg p "$package" 'select(.name==$p) | .version' "$package_dir/package.json") || die 'omp package metadata invalid'
  [[ $current =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die 'omp package version is not production semver'
  if [[ $action == install ]]; then echo 'omp already installed under mise Bun.'; exit 0; fi
else
  current=
fi
# Newest production release older than bunfig's minimumReleaseAge (7 days), so Bun accepts it.
cutoff=$(( $(date +%s) - 604800 ))
latest=$(curl --fail --silent --show-error --proto '=https' --max-time 60 'https://registry.npmjs.org/@oh-my-pi%2Fpi-coding-agent' \
  | jq -er --argjson cutoff "$cutoff" '.time as $t
      | [.versions | keys[] | select(test("^[0-9]+\\.[0-9]+\\.[0-9]+$"))
         | select(($t[.] | sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601) <= $cutoff)]
      | sort_by(split(".") | map(tonumber)) | last // empty') || die 'npm registry did not report an eligible production version'
[[ $latest =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die 'npm did not report a production version'
if [[ -n $current ]] && version_ge "$current" "$latest"; then echo "omp $current is at or ahead of production $latest"; exit 0; fi
bun add -g --ignore-scripts --registry https://registry.npmjs.org/ "$package@$latest"
[[ -L $omp_path && -e $omp_path && $(realpath "$omp_path") == "$(realpath "$package_dir")/"* ]] || die 'omp launcher ownership check failed'
[[ $(jq -er '.version' "$package_dir/package.json") == "$latest" ]] || die 'omp installed version differs from registry result'
