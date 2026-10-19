# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

This repository contains a comprehensive multi-platform Nix configuration for managing development environments, applications, and system settings across macOS and Linux systems using Nix Flakes. It supports multiple machine types (work laptop, media server) with shared configuration and machine-specific customizations.

## Machine Types

| Machine | Flake Target | Username | Purpose |
|---------|--------------|----------|---------|
| **macbook** | `.#macbook` | `waqas` | Personal MacBook - development environment |
| **work** | `.#work` | `waqas.ahmed` | Work MacBook - development environment |
| **mini** | `.#mini` | `waqas` | Mac Mini - media server with services |

## Common Commands

### System Building & Updating

#### Personal MacBook
```bash
./bootstrap.sh --machine macbook
sudo darwin-rebuild switch --flake ~/dev/dotnix#macbook
```

Use `--machine macbook` explicitly: username `waqas` is ambiguous between MacBook and Mini. Bootstrap defaults to a read-only plan; choose `--build-only` or explicit `--activate` after reviewing prerequisites.
After activation, `hs` uses the macbook target.

#### Work Mac
```bash
# Initial setup
./bootstrap.sh --machine work

# Apply changes after modifying configuration
sudo darwin-rebuild switch --flake ~/dev/dotnix#work

# Quick rebuild (uses alias 'hs' defined in shell)
hs
```

#### Mac Mini
```bash
# Initial setup
./bootstrap.sh --machine mini

# Apply changes
sudo darwin-rebuild switch --flake ~/dev/dotnix#mini
```

#### Linux/NixOS
```bash
# Home Manager only
home-manager switch --flake "$HOME/dev/dotnix#waqas.ahmed"

# Full NixOS system
sudo nixos-rebuild switch --flake ~/dev/dotnix#nixos
```

## Architecture

### Service Pattern (Mini)
Each service in `darwin/mini/services/` follows this pattern:
1. **Docker Compose file**: Managed by Nix, written to `~/.config/media-server/<service>/`
2. **Start script**: Fetches secrets from 1Password, generates private atomic `secrets.env`, starts containers
3. **launchd agent**: Auto-starts service on login
4. **Management scripts**: start/stop/logs/status/update commands

### 1Password Secret Pattern
Reuse the bounded secret reader in `darwin/mini/lib.nix`. Activation must not fetch optional vault data. Explicit service starts validate values, create private temporary files under `umask 077`, and replace output atomically. Mini Compose requires version 2.30+ for `env_file.format = raw`; do not use shell `eval` or unquoted dotenv interpolation for credentials. Preserve old output on failure and never print secrets. See the synthetic tests and Mini safety documentation.

## Troubleshooting

### Service won't start
```bash
# Check Docker is running
docker ps

# Check logs
<service>-logs

# Verify 1Password CLI works
op read "op://Private/test-item/password"
```

### Rebuild fails with "file not found"
```bash
# Git flakes see tracked files, including tracked local edits. Review new files first.
git add path/to/reviewed-new-file
sudo darwin-rebuild switch --flake ~/dev/dotnix#<machine>
```

### 1Password SSH agent not working
```bash
ssh-add -l  # Should list keys
# Check: 1Password → Settings → Developer → SSH agent enabled
```
