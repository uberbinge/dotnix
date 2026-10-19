#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

# --help exits after argument parsing, before any bootstrap phases run.
# Do not invoke the real bootstrap installation or activation during tests.
for machine in work macbook mini; do
    bash bootstrap.sh --machine "$machine" --help >/dev/null
    echo "PASS: bootstrap accepts --machine $machine"
done

if bash bootstrap.sh --machine mac-personal --help >/dev/null 2>&1; then
    echo "FAIL: bootstrap accepted the retired target" >&2
    exit 1
fi
echo "PASS: bootstrap rejects the retired target"

if bash bootstrap.sh --machine invalid --help >/dev/null 2>&1; then
    echo "FAIL: bootstrap accepted an invalid machine" >&2
    exit 1
fi
echo "PASS: bootstrap rejects an invalid machine"

if bash bootstrap.sh --machine >/dev/null 2>&1; then
    echo "FAIL: bootstrap accepted a missing machine" >&2
    exit 1
fi
echo "PASS: bootstrap rejects a missing machine"

if ! command -v nix-instantiate >/dev/null 2>&1; then
    echo "SKIP: generated hs and flake username tests require nix-instantiate" >&2
    exit 0
fi

# Pure unit evaluation with mocked module helpers; no inputs are downloaded,
# packages built, or machine configuration applied.
nix-instantiate --eval --strict tests/machine-targets.nix
echo "PASS: generated hs aliases and flake usernames"
