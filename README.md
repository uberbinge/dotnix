# dotnix

Nix configurations for personal/work Macs, a Mini server, standalone Linux Home Manager, and NixOS.

## Targets

| Target | User | Purpose |
|---|---|---|
| `macbook` | `waqas` | Personal development Mac |
| `work` | `waqas.ahmed` | Work development Mac |
| `mini` | `waqas` | Media/backup server |
| `homeConfigurations."waqas.ahmed"` | `waqas.ahmed` | Standalone Linux Home Manager |
| `nixos` | `waqas.ahmed` | NixOS; inspect its machine-specific filesystem UUIDs first |

## Prepare a Mac

Install Apple's Command Line Tools using `xcode-select --install` and complete the dialog. If it is not visible, check System Settings → General → Software Update. Verify `xcode-select -p` and `xcrun --find clang` before continuing.

Clone the public repository, inspect its scripts and configuration, and choose the target explicitly:

```bash
git clone https://github.com/uberbinge/dotnix.git ~/dev/dotnix
cd ~/dev/dotnix
less bootstrap.sh
less scripts/check-homebrew.sh
bash bootstrap.sh --machine macbook --plan
```

The default is a read-only plan, and `waqas` is deliberately ambiguous between `macbook` and `mini`. No force-delete or skipped-CLT option exists. Existing checkouts must be clean, on `main`, and use the expected origin before bootstrap updates them with `git pull --ff-only`; failures stop the process. For local changes, build them directly as shown below instead of bootstrap's update workflow.

If Nix is missing on a fresh machine, `bash bootstrap.sh --machine macbook --download-installer` downloads the official Lix shell wrapper to a temporary directory and prints its path and SHA-256. It does not execute it. Inspect the wrapper and downstream installer and review the installer plan, including encrypted `/nix`, daemon, shell, and administrator changes, before manually running the printed command. The printed hash identifies the download; it is not verification against an upstream signed checksum. If `/nix` already exists, diagnose it instead of reinstalling blindly.

Homebrew preflight allows a fresh prefix or a verified nix-homebrew-managed installation with the expected mutable-directory owners. Unknown/shared installations stop for deliberate migration review. Automatic migration is disabled. Do not fix this by recursively changing ownership or deleting an existing Homebrew installation. The same guard runs before direct Darwin activation.

## Inspect, build, and apply separately

```bash
cd ~/dev/dotnix
# Local status only: no authentication, Nix evaluation, or network tests.
bash scripts/dotnix-doctor.sh --machine macbook

# Evaluate locked configuration, preview downloads/source builds and app differences.
# May fetch flake inputs/cache metadata; does not build or activate.
bash scripts/dotnix-doctor.sh --machine macbook --plan

# Build local changes. New files must be tracked before Git-flake evaluation.
nix build --no-update-lock-file .#darwinConfigurations.macbook.system

# Only after reviewing the build and intended settings, apply explicitly:
sudo ./result/sw/bin/darwin-rebuild switch --flake .#macbook
```

Use the intended target consistently. A successful build does not install apps, update preferences, or prove activation succeeded. Bootstrap also provides `--build-only` and explicit `--activate`; both first update a clean checkout. Activation can change sudo Touch ID PAM, Nix daemon settings, Homebrew/app state, user configuration, and macOS preferences. It does not sign into 1Password. No script captures credentials or keeps sudo authorization alive.

After activation, follow [POST-SETUP-APPS.md](POST-SETUP-APPS.md). Save work and log out/in if input settings have not refreshed; verify gestures and shortcuts in the new session. Do not infer live behavior from saved preferences alone. `hs` activates configuration; it is not a health check.

## Apps, secrets, and recovery

- Homebrew cleanup remains disabled. `dotnix-doctor.sh --plan` reports declared-but-missing and installed-but-undeclared casks without uninstalling anything. Residual apps may be intentional. Review individual removals separately; no zap/data cleanup is performed.
- Alfred activation never reads the vault. Explicit work refresh is opt-in; see post-setup instructions. Failed refresh preserves the previous output.
- Mini services use bounded readiness/secret waits and require their existing Docker, vault, volume, and manually provisioned application prerequisites. See [Mini operational changes](darwin/mini/docs/backups-mini-server-retirement.md#startup-and-safety-behavior).
- Inspect available system generations with `darwin-rebuild --list-generations` before choosing a rollback. Review `darwin-rebuild --help` for the installed version's rollback command. Automatic Nix GC uses a seven-day policy; the manual `nix-cleanup` alias uses thirty days, and neither promises old generations remain available.
- Home Manager preserves unmanaged conflicts with `.backup`. If that backup already exists, compare and preserve both files before retrying. Never delete unknown configuration or overwrite a backup just to make activation pass.

## Linux

```bash
# Standalone Home Manager (no sudo / nixos-rebuild)
home-manager switch --flake '.#waqas.ahmed'

# NixOS only, after checking hardware/filesystem configuration
sudo nixos-rebuild switch --flake .#nixos
```

The corresponding `hs` alias follows the selected deployment mode.

## Local validation

```bash
bash scripts/test-machine-targets.sh
bash scripts/test-bootstrap.sh
bash scripts/test-doctor.sh
python3 scripts/test-alfred-sites.py
python3 scripts/test-mini-safety.py
bash scripts/public-safety-check.sh
```

These are local tests, not new CI coverage. No CI workflow changes accompany these improvements.

## Personal target migration

If the installed `hs` still names retired `mac-personal`, use an explicit `--flake ~/dev/dotnix#macbook` with your reviewed rebuild, then `exec zsh`. This target name does not change the Mac's network hostname.

## Structure

- `common/`: shared shell, editor, Git and utilities
- `darwin/work/`: shared development Mac applications
- `darwin/mini/`: server services and backups
- `linux/`: standalone Home Manager and machine-specific NixOS configuration
