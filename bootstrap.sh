#!/usr/bin/env bash
# Download this script to a file and review it before running; never curl | bash.
set -euo pipefail

fail() { printf 'Error: %s\n' "$*" >&2; return 1; }
usage() {
    cat <<'HELP'
Usage: ./bootstrap.sh --machine macbook|mini|work [OPTIONS]
  --plan, --dry-run     Read-only preflight and proposed commands (default).
  --build-only         Update clean main checkout and build; do not activate.
  --activate           Build, then explicitly apply the built system with sudo.
  --download-installer Download official Lix shell wrapper for manual review;
                       never execute it. Does not build or activate.
  --help               Show this help.
Username waqas requires explicit macbook or mini; waqas.ahmed defaults to work.
--force and --skip-xcode are deliberately unsupported. No files are removed.
Activation configures the Nix daemon, Homebrew ownership, Touch ID sudo PAM,
macOS preferences, apps and Home Manager. Review the configuration first.
Installer download is a shell wrapper, not a verified/inspected binary. Review
its downstream downloads and installer plan before approving installation.
HELP
}
parse_args() {
    MACHINE_TYPE=""; MODE=plan
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --machine)
                [ "$#" -ge 2 ] || { fail '--machine needs a value'; return 1; }
                case "$2" in work|macbook|mini) MACHINE_TYPE=$2;; *) fail 'unknown machine'; return 1;; esac
                shift 2;;
            --plan|--dry-run) MODE=plan; shift;;
            --build-only) MODE=build; shift;;
            --activate) MODE=activate; shift;;
            --download-installer) MODE=download; shift;;
            -h|--help) usage; return 2;;
            *) fail "unsupported option: $1"; return 1;;
        esac
    done
}
detect_machine_type() {
    if [ -z "$MACHINE_TYPE" ]; then
        case "$CURRENT_USER" in
            waqas.ahmed) MACHINE_TYPE=work;;
            waqas) fail 'Choose --machine macbook or --machine mini explicitly'; return 1;;
            *) fail "No configured target for username $CURRENT_USER"; return 1;;
        esac
    fi
    local expected=waqas
    [ "$MACHINE_TYPE" != work ] || expected=waqas.ahmed
    [ "$CURRENT_USER" = "$expected" ] || fail "$MACHINE_TYPE requires username $expected, found $CURRENT_USER"
}
check_xcode_prerequisites() {
    local developer_dir diagnostic
    if ! developer_dir=$(xcode-select -p 2>/dev/null) || [ ! -d "$developer_dir" ]; then
        fail 'Command Line Tools not selected. Run xcode-select --install in Terminal and finish the dialog; check Software Update if hidden.'
        return 1
    fi
    if ! diagnostic=$(xcrun clang --version 2>&1); then
        printf '%s\n' "$diagnostic" >&2
        fail "Selected developer tools at $developer_dir cannot run clang. If Xcode reports a license or first-launch requirement, review and complete it yourself in Terminal/Xcode; bootstrap never accepts licenses. Otherwise inspect xcode-select before reinstalling."
        return 1
    fi
    if ! diagnostic=$(/usr/bin/git --version 2>&1); then
        printf '%s\n' "$diagnostic" >&2
        fail "Selected developer tools at $developer_dir cannot run Git; resolve the reported license/setup issue locally."
        return 1
    fi
}

find_nix() {
    NIX_BIN=$(command -v nix || true)
    local candidate
    if [ -z "$NIX_BIN" ]; then
        for candidate in "$HOME/.nix-profile/bin/nix" /nix/var/nix/profiles/default/bin/nix /run/current-system/sw/bin/nix; do
            if [ -x "$candidate" ]; then NIX_BIN=$candidate; break; fi
        done
    fi
    [ -n "$NIX_BIN" ] && "$NIX_BIN" --version >/dev/null 2>&1
}
check_homebrew() {
    local helper
    helper="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/scripts/check-homebrew.sh"
    [ -f "$helper" ] || { fail "Missing $helper; use a complete reviewed repository checkout"; return 1; }
    bash "$helper" "$CURRENT_USER"
}
check_checkout() {
    [ -e "$CONFIG_DIR" ] || return 0
    [ -d "$CONFIG_DIR/.git" ] || { fail "$CONFIG_DIR exists and is not a checkout; nothing will be replaced"; return 1; }
    [ "$(git -C "$CONFIG_DIR" branch --show-current)" = main ] || { fail 'Checkout must be on main'; return 1; }
    [ -z "$(git -C "$CONFIG_DIR" status --porcelain)" ] || { fail 'Checkout has local changes; preserve/commit them before bootstrap update'; return 1; }
    local origin
    origin=$(git -C "$CONFIG_DIR" remote get-url origin)
    case "$origin" in https://github.com/uberbinge/dotnix.git|git@github.com:uberbinge/dotnix.git) ;; *) fail 'Unexpected origin; review it manually'; return 1;; esac
}
prepare_checkout() {
    check_checkout || return 1
    if [ -d "$CONFIG_DIR/.git" ]; then
        git -C "$CONFIG_DIR" pull --ff-only origin main
    else
        mkdir -p "$(dirname "$CONFIG_DIR")"
        # Public clone needs no credentials. SSH setup is a separate post-setup step.
        GIT_TERMINAL_PROMPT=0 git clone --branch main https://github.com/uberbinge/dotnix.git "$CONFIG_DIR"
    fi
}
main() {
    local rc=0
    parse_args "$@" || rc=$?
    [ "$rc" != 2 ] || return 0
    [ "$rc" = 0 ] || return "$rc"
    [ "$(id -u)" != 0 ] || { fail 'Run as your regular user, not sudo'; return 1; }
    [ "$(uname -s)" = Darwin ] || { fail 'This bootstrap requires macOS'; return 1; }
    [ "$(uname -m)" = arm64 ] || { fail 'Configured Mac targets require Apple Silicon; avoid Rosetta shells'; return 1; }
    CURRENT_USER=$(id -un)
    CONFIG_DIR="$HOME/dev/dotnix"
    detect_machine_type || return 1
    if [ "$MODE" = download ]; then
        local installer_dir
        installer_dir=$(mktemp -d "${TMPDIR:-/tmp}/dotnix-lix.XXXXXX")
        curl --fail --show-error --location --proto '=https' --tlsv1.2 https://install.lix.systems/lix -o "$installer_dir/lix-installer.sh"
        shasum -a 256 "$installer_dir/lix-installer.sh"
        printf 'Downloaded only; review wrapper and downstream installer before execution:\n  less %q\n' "$installer_dir/lix-installer.sh"
        printf 'After review, run locally (password and installer approval are yours):\n  sh %q install macos --encrypt true\nThen rerun bootstrap.\n' "$installer_dir/lix-installer.sh"
        return 0
    fi
    local ready=true
    check_xcode_prerequisites || ready=false
    check_homebrew || ready=false
    check_checkout || ready=false
    if ! find_nix; then
        printf 'Nix is absent or broken. If /nix already exists, repair it; do not reinstall blindly.\nUse --download-installer only for a reviewed fresh installation.\n' >&2
        ready=false
    fi
    printf 'Target: %s; mode: %s\n' "$MACHINE_TYPE" "$MODE"
    printf 'Proposed: clone/update clean main at %s; nix build .#darwinConfigurations.%s.system\n' "$CONFIG_DIR" "$MACHINE_TYPE"
    [ "$MODE" != activate ] || printf 'Then sudo the built darwin-rebuild switch --flake %s#%s\n' "$CONFIG_DIR" "$MACHINE_TYPE"
    if [ "$MODE" = plan ]; then
        printf 'Plan only: no downloads, writes, installation, or activation performed.\n'
        [ "$ready" = true ]; return
    fi
    [ "$ready" = true ] || { fail 'Resolve preflight failures before continuing'; return 1; }
    prepare_checkout
    "$NIX_BIN" --extra-experimental-features 'nix-command flakes' build --no-write-lock-file --no-update-lock-file "$CONFIG_DIR#darwinConfigurations.$MACHINE_TYPE.system" --out-link "$CONFIG_DIR/result"
    if [ "$MODE" = activate ]; then
        # Build and privilege acquisition are separate; no password capture/keepalive.
        sudo "$CONFIG_DIR/result/sw/bin/darwin-rebuild" switch --flake "$CONFIG_DIR#$MACHINE_TYPE"
        printf 'Activation exited successfully. Complete POST-SETUP-APPS.md and log out/in for GUI preferences.\n'
    else
        printf 'Build complete; not activated. Review then run:\n  sudo %q switch --flake %q\n' "$CONFIG_DIR/result/sw/bin/darwin-rebuild" "$CONFIG_DIR#$MACHINE_TYPE"
    fi
}
# Sourceable for synthetic tests; sourcing never performs bootstrap operations.
if [ "${BASH_SOURCE[0]}" = "$0" ]; then main "$@"; fi
