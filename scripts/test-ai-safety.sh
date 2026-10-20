#!/usr/bin/env bash
# Synthetic checks only; no vendor/network/install/activation invocation.
set -euo pipefail
repo=$(cd "$(dirname "$0")/.." && pwd)
for script in "$repo/scripts/local-target.sh" "$repo/scripts/local-nix.sh" "$repo/scripts/ai/"*.sh; do bash -n "$script"; done
source "$repo/scripts/ai/common.sh"

if (stage_script https://example.invalid/install.sh https://claude.ai/install.sh /dev/null) 2>/dev/null; then
  echo 'FAIL: foreign installer origin accepted' >&2; exit 1
fi
if version_ge 1.2.3 1.2.4; then echo 'FAIL: older version counted as current' >&2; exit 1; fi
version_ge 1.2.4 1.2.3
if (version_ge beta 1.0.0) 2>/dev/null; then echo 'FAIL: prerelease accepted' >&2; exit 1; fi
fixture=$(mktemp -d); trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/home/.local/bin" "$fixture/home/.local/share/collie/current/bin" "$fixture/other"
printf '#!/bin/sh\n' > "$fixture/home/.local/share/collie/current/bin/collie"
chmod +x "$fixture/home/.local/share/collie/current/bin/collie"
ln -s "$fixture/home/.local/share/collie/current/bin/collie" "$fixture/home/.local/bin/collie"
printf '#!/bin/sh\n' > "$fixture/other/collie"; chmod +x "$fixture/other/collie"
if (HOME="$fixture/home" PATH="$fixture/other:$fixture/home/.local/bin:$PATH"; native_launcher collie "$HOME/.local/share/collie") >/dev/null 2>&1; then
  echo 'FAIL: PATH collision accepted' >&2; exit 1
fi
if (HOME="$fixture/home" PATH="$fixture/home/.local/bin:$PATH"; native_launcher collie "$HOME/.local/share/claude") >/dev/null 2>&1; then
  echo 'FAIL: symlink accepted with missing owner directory' >&2; exit 1
fi
mkdir -p "$fixture/home/.local/share/claude"
if (HOME="$fixture/home" PATH="$fixture/home/.local/bin:$PATH"; native_launcher collie "$HOME/.local/share/claude") >/dev/null 2>&1; then
  echo 'FAIL: foreign symlink target accepted' >&2; exit 1
fi
if bash "$repo/scripts/ai/collie.sh" update macbook >/dev/null 2>&1; then
  echo 'FAIL: Collie update accepted a host argument' >&2; exit 1
fi
# A newer native Codex must never be replaced by the production "latest" tag.
mkdir -p "$fixture/home/.codex/packages/standalone/release/bin" "$fixture/mock"
cat > "$fixture/home/.codex/packages/standalone/release/bin/codex" <<'MOCK'
#!/bin/sh
echo 'codex-cli 0.164.0'
MOCK
chmod +x "$fixture/home/.codex/packages/standalone/release/bin/codex"
ln -s "$fixture/home/.codex/packages/standalone/release/bin/codex" "$fixture/home/.local/bin/codex"
cat > "$fixture/mock/uname" <<'MOCK'
#!/bin/sh
case "$1" in -s) echo Darwin;; -m) echo arm64;; esac
MOCK
cat > "$fixture/mock/id" <<'MOCK'
#!/bin/sh
case "$1" in -un) echo waqas;; -u) echo 501;; esac
MOCK
cat > "$fixture/mock/curl" <<'MOCK'
#!/bin/sh
case "$*" in
  *api.github.com/repos/openai/codex/releases/latest*) echo '{"tag_name":"rust-v0.163.0"}' ;;
  *) echo 'unexpected download' >&2; exit 71 ;;
esac
MOCK
chmod +x "$fixture/mock/"*
mock_path="$fixture/mock:$fixture/home/.local/bin:/usr/bin:/bin:/etc/profiles/per-user/waqas/bin"
result=$(HOME="$fixture/home" PATH="$mock_path" bash "$repo/scripts/ai/codex-cli.sh" update)
[[ $result == *'at or ahead of production'* ]] || { echo 'FAIL: Codex no-downgrade check' >&2; exit 1; }
mkdir -p "$fixture/home/.local/share/mise/installs/node/22.23.2/bin" \
  "$fixture/home/.local/share/mise/installs/node/22.23.2/lib/node_modules/@earendil-works/pi-coding-agent"
node_prefix="$fixture/home/.local/share/mise/installs/node/22.23.2"
cat > "$node_prefix/bin/node" <<'MOCK'
#!/bin/sh
echo v22.23.2
MOCK
cat > "$node_prefix/bin/npm" <<MOCK
#!/bin/sh
case "\$1 \$2 \$3" in
  'prefix -g ') echo '$node_prefix';;
  'config get registry') echo https://registry.npmjs.org/;;
  'view @earendil-works/pi-coding-agent version') echo 1.2.3;;
  *) echo 'unexpected npm mutation' >&2; exit 71;;
esac
MOCK
cat > "$fixture/mock/mise" <<MOCK
#!/bin/sh
case "\$1 \$2" in
  'which node') echo '$node_prefix/bin/node';;
  'which bun') echo '$fixture/home/.local/share/mise/installs/bun/1.4.3/bin/bun';;
  *) exit 71;;
esac
MOCK
chmod +x "$node_prefix/bin/node" "$node_prefix/bin/npm" "$fixture/mock/mise"
cat > "$node_prefix/lib/node_modules/@earendil-works/pi-coding-agent/package.json" <<'MOCK'
{"name":"@earendil-works/pi-coding-agent","version":"1.2.4"}
MOCK
printf '#!/bin/sh\n' > "$node_prefix/lib/node_modules/@earendil-works/pi-coding-agent/pi"
chmod +x "$node_prefix/lib/node_modules/@earendil-works/pi-coding-agent/pi"
ln -s "$node_prefix/lib/node_modules/@earendil-works/pi-coding-agent/pi" "$node_prefix/bin/pi"
pi_path="$fixture/mock:$node_prefix/bin:/usr/bin:/bin:/etc/profiles/per-user/waqas/bin"
result=$(HOME="$fixture/home" PATH="$pi_path" bash "$repo/scripts/ai/pi.sh" update)
[[ $result == *'at or ahead of production'* ]] || { echo 'FAIL: Pi no-downgrade check' >&2; exit 1; }
mkdir -p "$fixture/home/.local/share/collie/current/bin"
printf '#!/bin/sh\necho unexpected-service-action >&2; exit 71\n' > "$fixture/home/.local/share/collie/current/bin/collie"
chmod +x "$fixture/home/.local/share/collie/current/bin/collie"
if HOME="$fixture/home" PATH="$mock_path" bash "$repo/scripts/ai/collie.sh" update >/dev/null 2>&1; then
  echo 'FAIL: Collie update accepted without restart acknowledgment' >&2; exit 1
fi
# An already registered web UI is an install no-op, even when enabled; update
# still refuses to alter it. Mocks deny every network or mutation action.
bun_prefix="$fixture/home/.local/share/mise/installs/bun/1.4.3"
mkdir -p "$bun_prefix/bin"
cat > "$bun_prefix/bin/bun" <<'MOCK'
#!/bin/sh
echo 1.4.3
MOCK
cat > "$fixture/mock/herdr" <<'MOCK'
#!/bin/sh
printf '%s\n' "$*" >> "$HERDR_TEST_CALLS"
case "$*" in
  --version) echo 'herdr 0.9.5';;
  'plugin list --json') cat "$HERDR_TEST_INVENTORY";;
  *) echo 'unexpected Herdr mutation' >&2; exit 71;;
esac
MOCK
cat > "$fixture/mock/curl" <<'MOCK'
#!/bin/sh
echo 'unexpected network request' >&2
exit 71
MOCK
cat > "$fixture/mock/bashenv" <<'MOCK'
command() {
  if [[ ${1:-} == -v && ${2:-} == herdr ]]; then
    printf '%s\n' /opt/homebrew/bin/herdr
  else
    builtin command "$@"
  fi
}
MOCK
chmod +x "$bun_prefix/bin/bun" "$fixture/mock/herdr" "$fixture/mock/curl"
inventory="$fixture/herdr-inventory.json"; calls="$fixture/herdr-calls"
printf '%s\n' '{"result":{"plugins":[{"plugin_id":"devswha.herdr-web-ui","enabled":true,"source":{"kind":"github","owner":"devswha","repo":"herdr-web-ui"}}]}}' > "$inventory"
herdr_path="$fixture/mock:$node_prefix/bin:$bun_prefix/bin:/usr/bin:/bin"
result=$(HOME="$fixture/home" PATH="$herdr_path" BASH_ENV="$fixture/mock/bashenv" HERDR_TEST_INVENTORY="$inventory" HERDR_TEST_CALLS="$calls" bash "$repo/scripts/ai/herdr-web-ui.sh" install)
[[ $result == *'enabled=true'* && $result == *'existing service state unchanged'* ]] || { echo 'FAIL: existing Herdr plugin was not an install no-op' >&2; exit 1; }
[[ $(wc -l < "$calls" | tr -d ' ') == 2 ]] || { echo 'FAIL: Herdr install attempted an extra action' >&2; exit 1; }
if update_result=$(HOME="$fixture/home" PATH="$herdr_path" BASH_ENV="$fixture/mock/bashenv" HERDR_TEST_INVENTORY="$inventory" HERDR_TEST_CALLS="$calls" bash "$repo/scripts/ai/herdr-web-ui.sh" update 2>&1); then
  echo 'FAIL: Herdr update accepted an enabled plugin' >&2; exit 1
fi
[[ $update_result == *'disable and stop the web UI'* ]] || { echo 'FAIL: Herdr update failed before its enabled-plugin guard' >&2; exit 1; }
printf '%s\n' '{"result":{"plugins":[{"plugin_id":"devswha.herdr-web-ui","enabled":true,"source":{"kind":"github","owner":"foreign","repo":"herdr-web-ui"}}]}}' > "$inventory"
if foreign_result=$(HOME="$fixture/home" PATH="$herdr_path" BASH_ENV="$fixture/mock/bashenv" HERDR_TEST_INVENTORY="$inventory" HERDR_TEST_CALLS="$calls" bash "$repo/scripts/ai/herdr-web-ui.sh" install 2>&1); then
  echo 'FAIL: Herdr install accepted a foreign plugin source' >&2; exit 1
fi
[[ $foreign_result == *'plugin source is not selected upstream'* ]] || { echo 'FAIL: Herdr install failed before its source guard' >&2; exit 1; }
cat > "$fixture/mock/uname" <<'MOCK'
#!/bin/sh
case "$1" in -s) echo Darwin;; -m) echo x86_64;; esac
MOCK
chmod +x "$fixture/mock/uname"
if HOME="$fixture/home" PATH="$mock_path" bash "$repo/scripts/ai/codex-cli.sh" update >/dev/null 2>&1; then
  echo 'FAIL: wrong host architecture accepted' >&2; exit 1
fi
if HOME="$fixture/home" PATH="$mock_path" bash "$repo/scripts/ai/pi.sh" update macbook >/dev/null 2>&1; then
  echo 'FAIL: Pi accepted a host argument' >&2; exit 1
fi
if rg -n 'collie start|herdr (serve|plugin enable)|--enable' "$repo/scripts/ai"/*.sh >/dev/null; then
  echo 'FAIL: AI install scripts contain listener/enable action' >&2; exit 1
fi
echo 'PASS: AI script syntax, source, version, PATH, local platform, and no-listener guards'
