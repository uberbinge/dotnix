#!/usr/bin/env bash
# Shell functions below are intentional stubs called through sourced helpers.
# shellcheck disable=SC2329
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$root/bootstrap.sh"
expect_fail() { if "$@" >/dev/null 2>&1; then printf 'FAIL: expected rejection: %s\n' "$*"; exit 1; fi; }
parse_args --machine macbook --build-only
[ "$MODE" = build ] && [ "$MACHINE_TYPE" = macbook ]
parse_args --machine mini --activate
[ "$MODE" = activate ]
parse_args --machine work --dry-run
[ "$MODE" = plan ]
expect_fail parse_args --force
expect_fail parse_args --skip-xcode
expect_fail parse_args --machine
expect_fail parse_args --machine mac-personal
CURRENT_USER=waqas; MACHINE_TYPE=""; expect_fail detect_machine_type
MACHINE_TYPE=macbook; detect_machine_type
MACHINE_TYPE=mini; detect_machine_type
MACHINE_TYPE=work; expect_fail detect_machine_type
CURRENT_USER=waqas.ahmed; MACHINE_TYPE=""; detect_machine_type; [ "$MACHINE_TYPE" = work ]
CURRENT_USER=unknown; MACHINE_TYPE=work; expect_fail detect_machine_type
# Stubbed main plan must not invoke any mutating phase, even without Nix/CLT.
(
 temp=$(mktemp -d); trap 'rm -rf "$temp"' EXIT
 id() { case "$1" in -u) echo 501;; -un) echo waqas;; esac; }
 uname() { case "$1" in -s) echo Darwin;; -m) echo arm64;; esac; }
 check_xcode_prerequisites() { return 1; }
 check_homebrew() { return 0; }
 check_checkout() { return 0; }
 find_nix() { return 1; }
 prepare_checkout() { touch "$temp/mutation"; return 0; }
 sudo() { touch "$temp/mutation"; return 0; }
 curl() { touch "$temp/mutation"; return 0; }
 expect_fail main --machine macbook --plan
 [ ! -e "$temp/mutation" ]
)
# Pull errors must propagate, and unsafe checkouts must never be removed.
(
 temp=$(mktemp -d); trap 'rm -rf "$temp"' EXIT
 CONFIG_DIR="$temp/repo"; mkdir -p "$CONFIG_DIR/.git"
 check_checkout() { return 0; }
 git() { return 42; }
 expect_fail prepare_checkout
)
# CLT must be selected and xcrun must resolve a compiler; PATH git alone is insufficient.
(
 xcode-select() { return 1; }
 expect_fail check_xcode_prerequisites
 xcode-select() { echo /tmp; }
 xcrun() { echo 'Xcode license not accepted' >&2; return 69; }
 diagnostic=$(check_xcode_prerequisites 2>&1) && exit 1
 [[ "$diagnostic" == *'Xcode license not accepted'* ]]
 [[ "$diagnostic" == *'never accepts licenses'* ]]
)
# Repository preflight refuses dirty, unexpected branch, non-repo and wrong origin.
(
 temp=$(mktemp -d); trap 'rm -rf "$temp"' EXIT
 CONFIG_DIR="$temp/repo"; mkdir -p "$CONFIG_DIR"
 expect_fail check_checkout
 mkdir "$CONFIG_DIR/.git"
 branch=main; dirty=''; remote_url=https://github.com/uberbinge/dotnix.git
 git() { case "$3" in branch) echo "$branch";; status) printf '%s' "$dirty";; remote) echo "$remote_url";; *) return 1;; esac; }
 check_checkout
 dirty=' M file'; expect_fail check_checkout; dirty=''
 branch=feature; expect_fail check_checkout; branch=main
 remote_url=https://example.com/other.git; expect_fail check_checkout
)
# Homebrew fixture checks mock only ownership and store-link target, not filesystem.
(
 source "$root/scripts/check-homebrew.sh"
 temp=$(mktemp -d); trap 'rm -rf "$temp"' EXIT
 brew_owner() { echo waqas; }
 check_brew_prefix "$temp/absent" "$temp/absent/Library" waqas
 mkdir "$temp/prefix"
 check_brew_prefix "$temp/prefix" "$temp/prefix/Library" waqas
 mkdir -p "$temp/prefix/Library" "$temp/target"
 expect_fail check_brew_prefix "$temp/prefix" "$temp/prefix/Library" waqas
 touch "$temp/prefix/.managed_by_nix_darwin"
 ln -s "$temp/target" "$temp/prefix/Library/Homebrew"
 readlink() { echo /nix/store/test-brew/Library/Homebrew; }
 check_brew_prefix "$temp/prefix" "$temp/prefix/Library" waqas
 brew_owner() { case "$1" in */Library) echo waqar;; *) echo root;; esac; }
 expect_fail check_brew_prefix "$temp/prefix" "$temp/prefix/Library" waqas
)
printf 'PASS: bootstrap parsing, target identity, non-mutating plan, pull failure and Homebrew safety fixtures\n'
