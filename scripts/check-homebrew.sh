#!/usr/bin/env bash
# Read-only ownership/migration preflight, safe to call as root during activation.
set -euo pipefail
brew_error() { printf 'Homebrew preflight: %s\n' "$*" >&2; return 1; }
brew_owner() { /usr/bin/stat -f '%Su' "$1"; }
check_brew_prefix() {
    local prefix=$1 library=$2 expected=$3 marker owner path target
    [ -e "$prefix" ] || [ -L "$prefix" ] || return 0
    # Empty system-created directories need no migration.
    if [ -d "$prefix" ] && [ ! -L "$prefix" ] && [ -z "$(ls -A "$prefix")" ]; then
        owner=$(brew_owner "$prefix")
        case "$owner" in root|"$expected") return 0;; *) brew_error "$prefix belongs to $owner"; return 1;; esac
    fi
    [ -f "$prefix/.managed_by_nix_darwin" ] && [ ! -L "$prefix/.managed_by_nix_darwin" ] || {
        brew_error "$prefix exists but is not verified nix-homebrew-managed. Review migration manually; no ownership changes performed."; return 1;
    }
    [ ! -L "$prefix" ] && [ ! -L "$library" ] || { brew_error 'Unexpected symlink for mutable prefix/library'; return 1; }
    marker="$library/Homebrew"
    [ -L "$marker" ] && [ -d "$marker" ] || { brew_error "Missing or broken managed library $marker"; return 1; }
    target=$(readlink "$marker")
    case "$target" in /nix/store/*/Library/Homebrew) ;; *) brew_error "Unknown managed library target $target"; return 1;; esac
    owner=$(brew_owner "$prefix")
    case "$owner" in root|"$expected") ;; *) brew_error "$prefix belongs to $owner"; return 1;; esac
    # Check mutable roots only; never recursively follow links into /nix/store.
    for path in "$library" "$library/Taps" "$prefix/Cellar" "$prefix/Caskroom" "$prefix/bin"; do
        [ -e "$path" ] || [ -L "$path" ] || continue
        [ ! -L "$path" ] || { brew_error "Unexpected mutable directory symlink $path"; return 1; }
        owner=$(brew_owner "$path")
        [ "$owner" = "$expected" ] || { brew_error "$path belongs to $owner, expected $expected; review manually (no chown)"; return 1; }
    done
}
check_homebrew() {
    local expected=$1
    check_brew_prefix /opt/homebrew /opt/homebrew/Library "$expected" || return 1
    check_brew_prefix /usr/local /usr/local/Homebrew/Library "$expected"
}
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    [ "$#" = 1 ] || { brew_error 'Usage: check-homebrew.sh EXPECTED_USERNAME'; exit 1; }
    check_homebrew "$1"
fi
