# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

This repository contains a comprehensive multi-platform Nix configuration for managing development environments, applications, and system settings across macOS and Linux systems using Nix Flakes. It supports multiple machine types (work laptop, media server) with shared configuration and machine-specific customizations.

## Machine Types

| Machine | Flake Target | Username | Purpose |
|---------|--------------|----------|---------|
| **work** | `.#work` | `waqas.ahmed` | Work MacBook - development environment |
| **mini** | `.#mini` | `waqas` | Mac Mini - media server with services |

## Common Commands

### System Building & Updating

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
home-manager switch --flake ~/dev/dotnix

# Full NixOS system
sudo nixos-rebuild switch --flake ~/dev/dotnix
```

## Architecture

### Service Pattern (Mini)
Each service in `darwin/mini/services/` follows this pattern:
1. **Docker Compose file**: Managed by Nix, written to `~/.config/media-server/<service>/`
2. **Start script**: Fetches secrets from 1Password, generates `.env`, starts containers
3. **launchd agent**: Auto-starts service on login
4. **Management scripts**: start/stop/logs/status/update commands

### 1Password Secret Pattern
```bash
# In start scripts
DB_PASSWORD=$(op read "op://Private/<item>/password")
# Validate
if [ -z "$DB_PASSWORD" ]; then
  echo "ERROR: Failed to load secret" >&2
  exit 1
fi
# Write to .env (never committed)
echo "DB_PASSWORD=$DB_PASSWORD" > .env
```

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
# Nix flakes only see committed files
jj file track .
sudo darwin-rebuild switch --flake ~/dev/dotnix#<machine>
```

### 1Password SSH agent not working
```bash
ssh-add -l  # Should list keys
# Check: 1Password → Settings → Developer → SSH agent enabled
```
