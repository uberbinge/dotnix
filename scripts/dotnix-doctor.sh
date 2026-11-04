#!/usr/bin/env bash
# Read-only inspection. Never authenticate, build, activate, uninstall, or repair.
set -euo pipefail
usage() {
    cat <<'USAGE'
Usage: bash scripts/dotnix-doctor.sh --machine macbook|work|mini [--plan]
Default: local status only; no Nix evaluation or remote/authentication tests.
--plan: evaluate the locked target, show Nix's download/source-build plan,
        and compare installed Homebrew casks with evaluated declarations.
        May download flake inputs/cache metadata; never builds or activates.
USAGE
}
machine='' plan=false
while [ "$#" -gt 0 ]; do
    case "$1" in
        --machine)
            [ "$#" -ge 2 ] || { usage >&2; exit 2; }
            machine=$2; shift 2 ;;
        --plan) plan=true; shift ;;
        -h|--help) usage; exit 0 ;;
        *) usage >&2; exit 2 ;;
    esac
done
case "$machine" in macbook|work|mini) ;; *) usage >&2; exit 2 ;; esac
repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
expected=waqas
[ "$machine" != work ] || expected=waqas.ahmed
printf 'Target: %s; expected user: %s; actual user: %s\n' "$machine" "$expected" "$(id -un)"
printf 'Repository: %s\n' "$repo"
if command -v git >/dev/null 2>&1; then
    printf 'Desired revision: '
    git -C "$repo" rev-parse --short HEAD 2>/dev/null || printf 'unavailable\n'
    if [ -n "$(git -C "$repo" status --porcelain 2>/dev/null)" ]; then
        printf 'Working tree has changes; evaluated configuration includes tracked edits.\n'
    fi
fi
active=$(readlink /run/current-system 2>/dev/null || true)
printf 'Activated system link: %s\n' "${active:-absent or unreadable}"
printf 'Desired evaluation/build: not checked (use --plan). A build is not activation.\n'
if command -v nix >/dev/null 2>&1; then
    printf 'Nix command: %s; daemon health not tested.\n' "$(command -v nix)"
else
    printf 'Nix command: absent from PATH; try a new login shell after installation.\n'
fi
if xcode-select -p >/dev/null 2>&1 && xcrun --find clang >/dev/null 2>&1; then
    printf 'Command Line Tools: selected; compiler execution not tested.\n'
else
    printf 'Command Line Tools: selection/compiler unavailable.\n'
fi
for prefix in /opt/homebrew /usr/local/Homebrew; do
    if [ -d "$prefix" ]; then
        printf 'Homebrew prefix ownership (no changes): '
        ls -ld "$prefix"
    fi
done
brew_available=false
if command -v brew >/dev/null 2>&1; then
    brew_available=true
    printf 'Installed Homebrew casks (local list; not proof apps launch):\n'
    HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ANALYTICS=1 brew list --cask || brew_available=false
else
    printf 'Homebrew: absent from PATH; installed app inventory unavailable.\n'
fi
socket="$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
if [ -S "$socket" ]; then
    printf '1Password SSH socket: present; unlock/authorization NOT verified.\n'
else
    printf '1Password SSH socket: absent; unlock/authorization NOT verified.\n'
fi
if [ -f "$HOME/.ssh/config" ]; then
    printf 'SSH configuration file: present; contents and remote access NOT verified.\n'
else
    printf 'SSH configuration file: absent; remote access NOT verified.\n'
fi
printf 'Vault access/signing: NOT verified; no credentials read or prompts requested.\n'
cat <<'GUIDANCE'
Session: saved defaults do not prove live behavior. After a successful activation,
save work and log out/in if trackpad or shortcut settings have not refreshed.
Apps: undeclared casks can remain because cleanup is disabled; review before any removal.
Recovery: inspect `darwin-rebuild --list-generations` before selecting a rollback.
Garbage collection may remove old generations; do not assume recovery is available.
For Home Manager .backup collisions, compare and preserve both files before retrying;
do not delete backups blindly. Use explicit --flake PATH#TARGET during migration.
GUIDANCE
$plan || exit 0
if ! command -v nix >/dev/null 2>&1; then
    printf 'Plan unavailable: Nix is required.\n' >&2; exit 1
fi
tmp=$(mktemp -d "${TMPDIR:-/tmp}/dotnix-doctor.XXXXXX")
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
ref="$repo#darwinConfigurations.$machine"
# --no-write-lock-file prevents lock mutation; --no-update-lock-file refuses resolution drift.
if ! desired=$(nix eval --no-write-lock-file --no-update-lock-file --raw "$ref.system.outPath"); then
    printf 'Desired evaluation FAILED; no build/activation attempted.\n' >&2; exit 1
fi
printf 'Evaluated desired system: %s\n' "$desired"
if [ -d "$desired" ] && [ -f "$desired/activate" ]; then
    printf 'Built output: present locally (not proof of successful activation).\n'
else
    printf 'Built output: absent locally.\n'
fi
if [ -n "$active" ] && [ "$active" = "$desired" ]; then
    printf 'Activation: current-system points to desired output; post-activation health not verified.\n'
else
    printf 'Activation: current-system does not point to desired output.\n'
fi
printf '\nNix download/source-build plan (dry-run only):\n'
if ! nix build --no-write-lock-file --no-update-lock-file --dry-run --no-link "$ref.system"; then
    printf 'Build plan FAILED; no build/activation attempted.\n' >&2; exit 1
fi
# nix-darwin normalizes cask shorthand to entries with a name field.
if ! nix eval --no-write-lock-file --no-update-lock-file --raw "$ref.config.homebrew.casks" \
    --apply 'xs: builtins.concatStringsSep "\n" (map (x: if builtins.isString x then x else x.name) xs)' > "$tmp/declared.raw"; then
    printf 'Cask declaration evaluation FAILED; no removal recommended.\n' >&2; exit 1
fi
{ cat "$tmp/declared.raw"; printf '\n'; } | sed '/^$/d' | LC_ALL=C sort -u > "$tmp/declared"
printf '\nDeclared casks:\n'; cat "$tmp/declared"
if $brew_available; then
    if HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ANALYTICS=1 brew list --cask > "$tmp/installed.raw"; then
        LC_ALL=C sort -u "$tmp/installed.raw" > "$tmp/installed"
        printf '\nDeclared but not listed as installed:\n'
        LC_ALL=C comm -23 "$tmp/declared" "$tmp/installed"
        printf '\nInstalled but not declared (preview only; may be intentional):\n'
        LC_ALL=C comm -13 "$tmp/declared" "$tmp/installed"
    else
        printf 'Installed cask comparison unavailable: brew list failed.\n' >&2; exit 1
    fi
fi
printf '\nFinished inspection only. No build, activation, authentication, or app removal performed.\n'
