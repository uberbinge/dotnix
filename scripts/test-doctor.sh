#!/usr/bin/env bash
set -euo pipefail
# Optional script argument allows testing a staged copy before installation.
script=${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/dotnix-doctor.sh}
tmp=$(mktemp -d "${TMPDIR:-/tmp}/dotnix-doctor-test.XXXXXX")
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
mkdir -p "$tmp/bin" "$tmp/repo/scripts" "$tmp/home" "$tmp/built"
cp "$script" "$tmp/repo/scripts/dotnix-doctor.sh"
touch "$tmp/built/activate"
export DOCTOR_TEST_ROOT="$tmp"
cat > "$tmp/bin/nix" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$DOCTOR_TEST_ROOT/nix.calls"
[ "${FAIL_EVAL:-0}" != 1 ] || exit 1
case "$1" in
    eval)
        case "$*" in
            *homebrew.casks*) printf 'ghostty@tip\n1password' ;;
            *) printf '%s/built' "$DOCTOR_TEST_ROOT" ;;
        esac ;;
    build)
        case " $* " in *' --dry-run '*) ;; *) exit 90 ;; esac
        case " $* " in *' --no-link '*) ;; *) exit 91 ;; esac
        printf 'these 2 derivations will be built; 3 paths fetched (10 MiB download)\n' >&2 ;;
    *) exit 92 ;;
esac
STUB
cat > "$tmp/bin/brew" <<'STUB'
#!/usr/bin/env bash
[ "$*" = 'list --cask' ] || exit 93
printf 'ghostty@tip\nold-app\n'
STUB
cat > "$tmp/bin/git" <<'STUB'
#!/usr/bin/env bash
case "$*" in *rev-parse*) echo deadbee ;; *status*) ;; *) exit 94 ;; esac
STUB
cat > "$tmp/bin/readlink" <<'STUB'
#!/usr/bin/env bash
printf '%s/built\n' "$DOCTOR_TEST_ROOT"
STUB
for name in op ssh sudo darwin-rebuild; do
    cat > "$tmp/bin/$name" <<'STUB'
#!/usr/bin/env bash
printf 'FORBIDDEN\n' >> "$DOCTOR_TEST_ROOT/forbidden"
exit 95
STUB
 done
for name in xcode-select xcrun; do
    printf '#!/usr/bin/env bash\nexit 0\n' > "$tmp/bin/$name"
done
chmod +x "$tmp/bin/"*
export PATH="$tmp/bin:/usr/bin:/bin" HOME="$tmp/home"
run() { bash "$tmp/repo/scripts/dotnix-doctor.sh" "$@"; }
if run > "$tmp/no-target" 2>&1; then echo 'FAIL: no target accepted'; exit 1; fi
if run --machine unknown > /dev/null 2>&1; then echo 'FAIL: bad target accepted'; exit 1; fi
if run --machine > /dev/null 2>&1; then echo 'FAIL: missing target accepted'; exit 1; fi
for machine in work macbook mini; do run --machine "$machine" > "$tmp/status"; done
[ ! -e "$tmp/nix.calls" ]
grep -q 'NOT verified' "$tmp/status"
run --machine macbook --plan > "$tmp/plan" 2>&1
grep -q 'Built output: present locally' "$tmp/plan"
grep -q 'current-system points to desired' "$tmp/plan"
grep -q '2 derivations' "$tmp/plan"
grep -q '^1password$' "$tmp/plan"
grep -q '^old-app$' "$tmp/plan"
grep -q -- '--no-update-lock-file' "$tmp/nix.calls"
[ ! -e "$tmp/forbidden" ]
# Failed evaluation must stop before planning or app comparison.
: > "$tmp/nix.calls"
if FAIL_EVAL=1 run --machine mini --plan > "$tmp/failure" 2>&1; then
    echo 'FAIL: eval failure ignored'; exit 1
fi
grep -q 'Desired evaluation FAILED' "$tmp/failure"
[ "$(wc -l < "$tmp/nix.calls" | tr -d ' ')" = 1 ]
[ ! -e "$tmp/forbidden" ]
echo 'PASS: doctor parsing, no-eval default, dry-run plan, app preview, failure propagation, no authentication/activation'
