# dotnix

Multi-platform Nix configuration for development environments across macOS and Linux.

## Features

- **Comprehensive Setup**: 50+ applications, system preferences, development tools
- **Secure**: All secrets managed via 1Password integration
- **Modern Tools**: Neovim, tmux, zsh, GitHub CLI, modern alternatives (eza, bat, fd)
- **Cross-Platform**: Shared configuration with platform-specific optimizations

## Quick Start

```bash
# New Mac setup
curl -L https://raw.githubusercontent.com/uberbinge/dotnix/main/bootstrap.sh | bash

# After bootstrap
./sync-config-files.sh  # Sync configs from 1Password
```

## What's Included

- **Shell Environment**: zsh + Starship prompt, modern CLI tools
- **Editor**: Neovim with 40+ plugins, LSP, and productivity features  
- **System Config**: macOS preferences, Alfred workflows, SSH setup
- **Applications**: Development tools, productivity apps via Homebrew
- **Security**: 1Password SSH agent, secure credential management

## Daily Commands

```bash
darwin-rebuild switch --flake ~/dev/dotnix  # Apply changes (macOS)
home-manager switch --flake ~/dev/dotnix    # Apply changes (Linux)
nix flake update && darwin-rebuild switch --flake ~/dev/dotnix  # Update packages
```

## Structure

- `common/` - Shared configuration across platforms
- `darwin/` - macOS-specific settings and applications
- `linux/` - Linux/NixOS configurations
- `bootstrap.sh` - Automated setup script

Ready for development in minutes, not hours.