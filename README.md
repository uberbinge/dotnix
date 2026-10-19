# dotnix

Multi-machine Nix configuration for macOS systems.

## Machines

| Machine | Purpose | Flake Target |
|---------|---------|--------------|
| **macbook** | Personal development MacBook (`waqas`) | `.#macbook` |
| **work** | Development MacBook | `.#work` |
| **mini** | Media server (Jellyfin, Immich, Paperless, Home Assistant) | `.#mini` |

## Quick Start

```bash
# Install Xcode CLI tools first
sudo xcode-select --install

# Run bootstrap (auto-detects machine type)
curl -L https://raw.githubusercontent.com/uberbinge/dotnix/main/bootstrap.sh | bash

# Personal Mac: select explicitly (waqas otherwise defaults to mini)
./bootstrap.sh --machine macbook
```

## Daily Usage

```bash
# Rebuild after config changes
sudo darwin-rebuild switch --flake ~/dev/dotnix#work  # or #macbook / #mini

# Update packages
nix flake update && sudo darwin-rebuild switch --flake ~/dev/dotnix#work

# Public repo safety check before pushing
bash scripts/public-safety-check.sh
```

## Structure

- `common/` - Shared config (shell, neovim, git)
- `darwin/work/` - Shared development Mac apps and packages
- `darwin/mini/` - Media server services
- `linux/` - NixOS config

## Personal Mac target migration

The personal target is now `macbook`. If your installed `hs` still uses the retired
`mac-personal` target, run this once instead of `hs`:

```bash
sudo darwin-rebuild switch --flake ~/dev/dotnix#macbook
exec zsh
```

After successful activation, `hs` selects `macbook`. This target name does not
change the Mac’s network hostname. Work and Mini target behavior is unchanged.
