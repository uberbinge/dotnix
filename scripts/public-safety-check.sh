#!/usr/bin/env bash
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

failures=0

fail() {
  local label="$1"
  failures=$((failures + 1))
  echo "FAIL: ${label}" >&2
}

check() {
  local label="$1"
  local pattern="$2"
  shift 2

  echo "==> ${label}"
  if rg -n --hidden --glob '!.git/' --glob '!flake.lock' "$pattern" "$@"; then
    fail "$label"
  else
    echo "OK"
  fi
  echo
}

check_paths() {
  local label="$1"
  local pattern="$2"

  echo "==> ${label}"
  if git ls-files | rg -n "$pattern"; then
    fail "$label"
  else
    echo "OK"
  fi
  echo
}

check \
  "private key material" \
  'BEGIN (OPENSSH|RSA|EC|DSA|PRIVATE) PRIVATE KEY|OPENSSH PRIVATE KEY' \
  --glob '!scripts/public-safety-check.sh' \
  --glob '!darwin/mini/docs/public-safety.md' \
  .

check_paths \
  "tracked runtime files" \
  '(^|/)\.env($|[.])|(^|/)id_rsa$|(^|/)logs/.*-key\.txt$|(^|/)health\.db$|(^|/)bulk-data-raw\.json$'

check \
  "hardcoded borg passphrases or known test passphrases" \
  'encryption_passphrase:|BORG_PASSPHRASE=["'\''][^"$]|1testpass' \
  --glob '!scripts/public-safety-check.sh' \
  --glob '!darwin/mini/docs/public-safety.md' \
  .

check \
  "hardcoded API tokens" \
  '(TELEGRAM_.*TOKEN|CLOUDFLARE_API_TOKEN|GITHUB_TOKEN|OPENAI_API_KEY|ANTHROPIC_API_KEY)=['\''"]?[A-Za-z0-9_./:+-]{8,}' \
  --glob '!scripts/public-safety-check.sh' \
  --glob '!darwin/mini/docs/public-safety.md' \
  .

check \
  "Hetzner Storage Box account IDs" \
  'u[0-9]{6}(-sub[0-9]+)?' \
  --glob '!scripts/public-safety-check.sh' \
  --glob '!darwin/mini/docs/public-safety.md' \
  .

if [ "$failures" -gt 0 ]; then
  echo "$failures public-safety check(s) failed." >&2
  exit 1
fi

echo "Public-safety checks passed."
