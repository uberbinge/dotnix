# dotnix

Multi-machine Nix configuration for macOS systems.

## Machines

| Machine | Purpose | Flake Target |
|---------|---------|--------------|
| **work** | Development MacBook | `.#work` |
| **mini** | Media server (Jellyfin, Immich, Paperless, Home Assistant) | `.#mini` |

## Quick Start

```bash
# Install Xcode CLI tools first
sudo xcode-select --install

# Run bootstrap (auto-detects machine type)
curl -L https://raw.githubusercontent.com/uberbinge/dotnix/main/bootstrap.sh | bash

# Or specify machine type
./bootstrap.sh --machine mini
```

## Daily Usage

```bash
# Rebuild after config changes
sudo darwin-rebuild switch --flake ~/dev/dotnix#work  # or #mini

# Update packages
nix flake update && sudo darwin-rebuild switch --flake ~/dev/dotnix#work
```

## Structure

- `common/` - Shared config (shell, neovim, git)
- `darwin/work/` - Work Mac specific
- `darwin/mini/` - Media server services
- `linux/` - NixOS config
