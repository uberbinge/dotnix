# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

This repository contains a comprehensive multi-platform Nix configuration for managing development environments, applications, and system settings across macOS and Linux systems using Nix Flakes. It supports multiple machine types (work laptop, media server) with shared configuration and machine-specific customizations.

## Machine Types

| Machine | Flake Target | Username | Purpose |
|---------|--------------|----------|---------|
| **work** | `.#work` | `waqas.ahmed` | Work MacBook - development environment |
| **mini** | `.#mini` | `waqas` | Mac Mini - media server with services |

## Repository Structure

```
flake.nix                 # Main flake with multi-machine system definitions
├── bootstrap.sh          # Multi-machine setup script (supports --machine work/mini)
├── sync-config-files.sh  # 1Password config file synchronization
├── POST-SETUP-APPS.md    # Post-installation manual app configuration guide
├── common/               # Shared configuration across all platforms
│   ├── home.nix          # Core Home Manager config with shell setup
│   ├── nixvim.nix        # Comprehensive Neovim configuration
│   ├── vcs.nix           # Git & Jujutsu (jj) version control configuration
│   └── scripts.nix       # Custom shell scripts and utilities
├── darwin/               # macOS-specific configurations
│   ├── configuration.nix # System-level macOS settings
│   ├── defaults.nix      # macOS system preferences & keyboard shortcuts
│   ├── alfred.nix        # Alfred workflows and shortcuts
│   ├── home.nix          # macOS-specific home configuration
│   ├── lib.nix           # Shared utilities for darwin modules
│   ├── work/             # Work Mac specific config
│   │   └── homebrew.nix  # Work-specific apps
│   ├── mini/             # Mac Mini media server
│   │   ├── default.nix   # Mini home-manager config
│   │   ├── lib.nix       # Mini-specific utilities
│   │   ├── homebrew.nix  # Mini-specific apps
│   │   ├── borgmatic.nix # Backup to Hetzner Storage Box
│   │   ├── caddy.nix     # Reverse proxy
│   │   ├── scripts.nix   # Mini management scripts
│   │   └── services/     # Docker-based services
│   │       ├── home-assistant.nix
│   │       ├── immich.nix
│   │       ├── jellyfin.nix
│   │       └── paperless.nix
│   ├── homebrew/         # Shared homebrew configurations
│   │   ├── common.nix
│   │   ├── development.nix
│   │   └── productivity.nix
│   └── alfred-workflows/ # Alfred workflow files
└── linux/                # Linux/NixOS configurations
    ├── configuration.nix
    └── home.nix
```

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

### Mac Mini Service Commands

Each service has consistent management commands:

| Service | Start | Stop | Logs | Status | Update |
|---------|-------|------|------|--------|--------|
| Jellyfin | `jellyfin-start` | `jellyfin-stop` | `jellyfin-logs` | `jellyfin-status` | `jellyfin-update` |
| Immich | `immich-start` | `immich-stop` | `immich-logs` | `immich-status` | `immich-update` |
| Paperless | `paperless-start` | `paperless-stop` | `paperless-logs` | `paperless-status` | `paperless-update` |
| Home Assistant | `ha-start` | `ha-stop` | `ha-logs` | `ha-status` | `ha-update` |
| Borgmatic | `borgmatic-start` | `borgmatic-stop` | `borgmatic-logs` | `borgmatic-status` | - |

#### Borgmatic Backup Commands
```bash
borgmatic-backup <service>   # Run backup for immich/jellyfin/paperless
borgmatic-list <service>     # List archives
borgmatic-info <service>     # Show repo info
borgmatic-init <service>     # Initialize new repo
```

### Service URLs (Mac Mini)
- **Jellyfin**: http://localhost:8096
- **Immich**: http://localhost:2283
- **Paperless**: http://localhost:8000
- **Home Assistant**: http://localhost:8123

## Key Features

### Core Functionality
- **Multi-Machine Support**: Work laptop and media server from same codebase
- **Declarative System Management**: Everything defined in code, reproducible
- **Lix Package Manager**: Community Nix fork with better UX
- **1Password Integration**: All secrets managed via 1Password CLI

### Mac Mini Services
- **Jellyfin**: Media streaming server
- **Immich**: Photo management (Google Photos alternative)
- **Paperless-ngx**: Document management with OCR
- **Home Assistant**: Home automation
- **Borgmatic**: Encrypted backups to Hetzner Storage Box
- **Caddy**: Reverse proxy with automatic HTTPS

### Security & Secrets
- **1Password SSH Agent**: Git signing and SSH operations
- **Runtime Secret Fetching**: Secrets fetched via `op read` at service start
- **No Hardcoded Credentials**: All passwords in 1Password
- **Encrypted Backups**: Borg encryption with passphrase in 1Password

## Architecture

### Flake Configurations
```nix
darwinConfigurations = {
  work = mkConfiguration { username = "waqas.ahmed"; hostname = "work"; ... };
  mini = mkConfiguration { username = "waqas"; hostname = "mini"; ... };
};
```

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

## Adding a New Service (Mini)

1. Create `darwin/mini/services/<service>.nix`
2. Add to imports in `darwin/mini/default.nix`
3. Create 1Password items for any secrets
4. Rebuild: `sudo darwin-rebuild switch --flake ~/dev/dotnix#mini`
5. Start: `<service>-start`

## Adding a New Backup (Borgmatic)

1. Create Hetzner sub-account (e.g., `sub4`)
2. Add SSH public key to sub-account
3. Add known_hosts entry in `borgmatic.nix`
4. Add backup config using `mkBorgmaticConfig`
5. Add volume mount in docker-compose section
6. Add cron schedule
7. Rebuild and run `borgmatic-init <service>`

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
git add .
sudo darwin-rebuild switch --flake ~/dev/dotnix#<machine>
```

### 1Password SSH agent not working
```bash
ssh-add -l  # Should list keys
# Check: 1Password → Settings → Developer → SSH agent enabled
```

## Bootstrap Script

```bash
# Auto-detect machine type (by username)
./bootstrap.sh

# Explicit machine type
./bootstrap.sh --machine work
./bootstrap.sh --machine mini

# Dry run
./bootstrap.sh --machine mini --dry-run
```

The script:
1. Installs Lix (Nix fork)
2. Clones this repository
3. Runs `darwin-rebuild switch --flake .#<machine>`
4. Shows machine-specific next steps
