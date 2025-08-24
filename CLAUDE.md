# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

This repository contains a comprehensive multi-platform Nix configuration for managing development environments, applications, and system settings across macOS and Linux systems using Nix Flakes.

## Repository Structure

```
flake.nix                 # Main flake with multi-platform system definitions
├── bootstrap.sh         # Idempotent MacBook setup script
├── sync-config-files.sh  # 1Password config file synchronization
├── common/               # Shared configuration across all platforms
│   ├── home.nix         # Core Home Manager config with shell setup
│   ├── nixvim.nix       # Comprehensive Neovim configuration
│   ├── packages.nix     # Common packages for all systems
│   └── scripts.nix      # Custom shell scripts and utilities
├── darwin/              # macOS-specific configurations
│   ├── configuration.nix  # System-level macOS settings
│   ├── homebrew.nix       # GUI apps and Mac App Store apps
│   ├── defaults.nix       # macOS system preferences
│   ├── alfred.nix         # Alfred workflows and shortcuts
│   └── home.nix          # macOS-specific home configuration
└── linux/               # Linux/NixOS configurations
    ├── configuration.nix  # Linux system configuration
    └── home.nix          # Linux-specific home configuration
```

## Common Commands

### System Building & Updating

#### macOS Commands
```bash
# Initial setup
nix run nix-darwin -- switch --flake .

# Apply changes after modifying configuration
darwin-rebuild switch --flake ~/dev/dotnix

# Update packages to latest versions
nix flake update
darwin-rebuild switch --flake ~/dev/dotnix
```

#### Linux/NixOS Commands
```bash
# Home Manager only (uses current user automatically)
home-manager switch --flake ~/dev/dotnix

# Full NixOS system
sudo nixos-rebuild switch --flake ~/dev/dotnix
```

### Development Commands

```bash
# Check Nix configuration formatting
nix run nixpkgs#nixpkgs-fmt -- --check .

# Format Nix files
nix run nixpkgs#nixpkgs-fmt -- .

# Open a development shell with Nix tools
nix develop

# Sync config files from 1Password
./sync-config-files.sh

# Update homebrew apps (macOS only)
update-homebrew-apps
```

## Key Features

### Core Functionality
- Multi-platform support (macOS/Linux)
- Declarative system configuration
- Comprehensive Neovim setup with 40+ plugins
- Advanced shell environment with zsh, tmux, and modern CLI tools
- Custom productivity scripts
- GitHub CLI integration with SSH-first configuration
- macOS regional settings (Celsius, Metric, Monday first day)
- Window management preferences (always prefer tabs)

### Custom Scripts & Workflows
- `tmux-sessionizer`: Quick project navigation tool (Ctrl+X)
- `update_find_cache.sh`: Maintains directory cache for fast project navigation
- `sync-config-files.sh`: Syncs config files from 1Password to proper locations
- `update-homebrew-apps`: Updates all homebrew packages while preserving browser extensions
- **Alfred workflows**: Pre-configured shortcuts for development sites and tools

### Modern Security & Environment Management
- **1Password Integration**: Environment variables managed via `op://` references in Nix
- **1Password SSH Agent**: Git signing and SSH operations handled by 1Password
- **Tailscale SSH**: Machine-to-machine access without manual key management
- **Config File Sync**: AWS, NPM, Gradle configs synced from 1Password family vault
- **Cross-platform Support**: SSH signing works on both macOS and Linux
- **Automatic User Detection**: Username automatically detected from `$USER` environment variable

### Keyboard Shortcuts & System Integration
- **Spotlight shortcuts disabled**: Frees up Cmd+Space for Alfred
- **GitHub CLI integration**: Automatic credential management for git operations
- **Touch ID authentication**: Enabled for sudo operations

## Architecture Overview

This repository uses Nix Flakes to manage system configurations. The central `flake.nix` file defines inputs (dependencies) and outputs (configurations) for different systems. It uses a modular approach with a `mkConfiguration` function that creates system configurations based on platform-specific parameters.

Key architectural components:
1. **Flake Inputs**: Core dependencies like nixpkgs, home-manager, and nix-darwin
2. **Common Configuration**: Shared settings across platforms
3. **Platform-specific Modules**: Separate configurations for macOS and Linux
4. **Home Manager**: User environment configuration
5. **Custom Scripts**: Productivity and maintenance utilities

## Security Notes

- **1Password Family Account**: All secrets managed in `Private` vault at `my.1password.eu`
- **SSH Signing**: Git commits signed using 1Password SSH Agent
- **Environment Variables**: Securely loaded via `op://` references in Nix configuration
- **Config Files**: AWS, NPM, Gradle properties synced from 1Password on demand
- **Touch ID**: Enabled for sudo authentication on macOS
- **No Manual Key Management**: SSH keys handled entirely by 1Password SSH Agent

## Configuration Areas

### System Preferences (darwin/defaults.nix)
- **Regional/Format Settings**: Temperature (Celsius), Measurement (Metric), Date format (DD/MM/YYYY), Number format (1,234,567.89)
- **Window Management**: Always prefer tabs when opening documents
- **Keyboard Shortcuts**: Spotlight shortcuts disabled (60, 64, 65) to free Cmd+Space for Alfred
- **Clock Display**: 24-hour format enabled

### Development Tools (common/home.nix)
- **GitHub CLI**: SSH protocol preference, nvim editor, automatic git credential integration
- **Shell Environment**: Zsh with Starship prompt, modern CLI tools (eza, bat, fd, ripgrep)
- **History Management**: Atuin for enhanced shell history with sync capabilities
- **Git Configuration**: SSH signing with 1Password, cross-platform compatibility
- **Environment Variables**: API keys, Gradle credentials via 1Password integration

### Alfred Integration (darwin/alfred.nix)
- **Custom Workflows**: Pre-configured shortcuts for development sites
- **Site Shortcuts**: Quick access to GitHub repos, Grafana dashboards, backoffice tools
- **Icon Management**: Custom icons for different services and tools