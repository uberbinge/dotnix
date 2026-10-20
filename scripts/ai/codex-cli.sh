#!/usr/bin/env bash
# https://developers.openai.com/codex/cli - standalone production channel.
set -euo pipefail
source "$(dirname "$0")/common.sh"
action=${1:-}; [[ $# == 1 ]] || die 'usage: codex-cli.sh install|update'; guard_local_ai
[[ $action == install || $action == update ]] || die 'usage: codex-cli.sh install|update'
root="$HOME/.codex/packages/standalone"
if launcher=$(native_launcher codex "$root"); then
  [[ $action != install ]] && echo 'Checking current Codex production release.' || { echo 'Codex CLI already installed from OpenAI standalone channel.'; exit 0; }
fi
tag=$(latest_tag openai/codex); latest=${tag#rust-v}; latest=${latest#v}
if [[ -n ${launcher:-} ]]; then
  current=$("$launcher" --version | sed -nE 's/^codex-cli ([0-9]+\.[0-9]+\.[0-9]+)$/\1/p')
  [[ -n $current ]] || die 'unrecognized Codex CLI version'
  if version_ge "$current" "$latest"; then echo "Codex $current is at or ahead of production $latest"; exit 0; fi
fi
temp=$(mktemp -d); trap 'rm -rf "$temp"' EXIT
stage_script https://chatgpt.com/codex/install.sh https://chatgpt.com/codex/install.sh "$temp/install.sh"
# OpenAI installer verifies its release archive against published SHA-256 data.
CODEX_RELEASE=latest sh "$temp/install.sh" --release latest
native_launcher codex "$root" >/dev/null || die 'OpenAI standalone launcher missing after install'
