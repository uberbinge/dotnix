#!/usr/bin/env bash
# Synthetic checks only; no vendor/network/install/activation invocation.
set -euo pipefail
repo=$(cd "$(dirname "$0")/.." && pwd)
for script in "$repo/scripts/check-target.sh" "$repo/scripts/local-target.sh" "$repo/scripts/local-nix.sh" "$repo/scripts/ai/"*.sh; do bash -n "$script"; done
source "$repo/scripts/ai/common.sh"

if (stage_script https://example.invalid/install.sh https://claude.ai/install.sh /dev/null) 2>/dev/null; then
  echo 'FAIL: foreign installer origin accepted' >&2; exit 1
fi
if version_ge 1.2.3 1.2.4; then echo 'FAIL: older version counted as current' >&2; exit 1; fi
version_ge 1.2.4 1.2.3
if (version_ge beta 1.0.0) 2>/dev/null; then echo 'FAIL: prerelease accepted' >&2; exit 1; fi
if bash "$repo/scripts/check-target.sh" invalid >/dev/null 2>&1; then
  echo 'FAIL: unknown host target accepted' >&2; exit 1
fi

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
  echo 'FAIL: wrong symlink owner accepted' >&2; exit 1
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
case "\$1 \$2" in 'which node') echo '$node_prefix/bin/node';; *) exit 71;; esac
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
