#!/usr/bin/env bash
# Shared safety primitives only; each tool keeps its own installer/update policy.
set -euo pipefail
AI_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
die() { printf 'AI setup: %s\n' "$*" >&2; exit 3; }
guard_local_ai() {
  local system arch user
  system=$(uname -s); arch=$(uname -m); user=$(id -un)
  [[ $(id -u) != 0 ]] || die 'run as a regular user'
  case "$system/$arch/$user" in
    Darwin/arm64/waqas|Darwin/arm64/waqas.ahmed|Linux/aarch64/waqas.ahmed) ;;
    *) die "unsupported local user/platform: $user on $system/$arch" ;;
  esac
}
guard_local_mac() {
  guard_local_ai
  [[ $(uname -s) == Darwin ]] || die 'this plugin requires Brew Herdr on macOS'
}
need() { command -v "$1" >/dev/null 2>&1 || die "missing $1; apply hs and install runtimes first"; }
stage_script() {
  local url=$1 expected=$2 output=$3 final
  [[ $url == "$expected" && $url == https://* ]] || die "untrusted installer source: $url"
  need curl
  final=$(curl --fail --silent --show-error --location --proto '=https' --proto-redir '=https' \
    --max-time 60 --max-filesize 2000000 --output "$output" --write-out '%{url_effective}' "$url") || die "failed to fetch $url"
  [[ $final == "$expected" && -s $output ]] || die "installer redirected away from $expected or is empty"
  head -c 2 "$output" | grep -q '^#!' || die 'unexpected installer content'
  shasum -a 256 "$output"
}
native_launcher() {
  local name=$1 root=$2 canonical="$HOME/.local/bin/$1" first found other root_real launcher_real
  first=$(command -v "$name" 2>/dev/null || true)
  [[ -n $first || -L $canonical ]] || return 1
  [[ $first == "$canonical" && -L $canonical && -e $canonical ]] || die "$name has another PATH owner or invalid native launcher"
  found=$(type -a -p "$name" 2>/dev/null | sort -u)
  while IFS= read -r other; do
    [[ -z $other || $other == "$canonical" ]] || die "$name has duplicate PATH owner $other"
  done <<< "$found"
  [[ -d $root ]] || die "$name owner directory is missing: $root"
  root_real=$(realpath "$root") || die "$name owner directory cannot be resolved: $root"
  launcher_real=$(realpath "$canonical") || die "$name launcher cannot be resolved"
  [[ $launcher_real == "$root_real/"* ]] || die "$name launcher does not point under $root"
  printf '%s\n' "$canonical"
}
version_ge() {
  [[ $1 =~ ^[0-9]+\.[0-9]+\.[0-9]+$ && $2 =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die 'invalid production version'
  awk -v a="$1" -v b="$2" 'BEGIN {split(a,x,"."); split(b,y,"."); for(i=1;i<=3;i++){if(x[i]+0>y[i]+0)exit 0;if(x[i]+0<y[i]+0)exit 1}exit 0}'
}
latest_tag() {
  local repo=$1 tag
  need curl; need jq
  tag=$(curl --fail --silent --show-error --proto '=https' --max-time 30 \
    "https://api.github.com/repos/$repo/releases/latest" | jq -er '.tag_name') || die "cannot read $repo production release"
  [[ $tag =~ ^(rust-)?v?[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "unexpected production release tag: $tag"
  printf '%s\n' "$tag"
}
