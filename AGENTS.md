# Repository Guidelines

## Project Structure & Module Organization
- `flake.nix` is the single source of truth for macOS (`darwin/`) and Linux (`linux/`) system definitions, with cross-platform modules under `common/`.
- Shell scripts such as `bootstrap.sh`, `sync-config-files.sh`, and helpers declared in `common/scripts.nix` live at the repo root; run them from `/Users/waqas.ahmed/dev/dotnix`.
- Alfred workflows and icons sit in `darwin/alfred-workflows/` and `darwin/alfred-icons/`; they are tracked assets and should be updated together.
- Local-only notes belong in `CLAUDE.local.md`; keep secrets out of git and prefer 1Password references inside Nix expressions.

## Build, Test, and Development Commands
```bash
# macOS: rebuild the full system after edits
darwin-rebuild switch --flake ~/dev/dotnix

# Linux: apply home-manager changes (no sudo)
home-manager switch --flake ~/dev/dotnix

# Update inputs, then rebuild
nix flake update && darwin-rebuild switch --flake ~/dev/dotnix

# Lint Nix formatting
nix run nixpkgs#nixpkgs-fmt -- --check .
```

## Coding Style & Naming Conventions
- Format Nix files with `nixpkgs-fmt`; keep two-space indentation and align attribute sets for readability.
- Prefer declarative module naming: `<platform>/<area>.nix` (e.g., `darwin/homebrew.nix`) and keep script names lowercase with hyphens.
- When adding options, group related settings underneath descriptive comments rather than scattered single-line notes.

## Testing Guidelines
- Run `nix flake check` before opening a pull request; it validates module evaluation and options.
- New modules should expose `checks` or `packages` so CI can verify them; mirror existing patterns in `common/home.nix`.
- For shell scripts, add smoke tests via Nix derivations or document manual verification steps inside the script header.

## Commit & Pull Request Guidelines
- Follow the short imperative style visible in `git log` (e.g., `update ghostty theme syntax`); keep the first line ≤ 72 characters and skip punctuation.
- Bundle related configuration updates into a single commit; split platform-specific changes when they touch separate directories.
- Pull requests should describe the affected machines, include the exact rebuild command run, and note any required manual steps (screenshots for Alfred changes are helpful).

## Security & Configuration Tips
- Store credentials in 1Password and reference them through existing fetch scripts rather than embedding secrets.
- When adding third-party sources, pin them via the flake inputs and document their update cadence in `POST-SETUP-APPS.md`.
