# dotnix

Multi-platform Nix configuration for development environments across macOS and Linux.

## Features

- **Comprehensive Setup**: 50+ applications, system preferences, development tools
- **Secure**: All secrets managed via 1Password integration
- **Modern Tools**: Neovim, tmux, zsh, GitHub CLI, modern alternatives (eza, bat, fd)
- **Cross-Platform**: Shared configuration with platform-specific optimizations

## Quick Start

### New MacBook Setup

**Prerequisites (manual step):**
```bash
# 1. Install Xcode Command Line Tools first
sudo xcode-select --install
# Wait for installation to complete (5-15 minutes)

# 2. Verify installation
git --version
make --version
```

**Automated setup:**
```bash
# 3. Run bootstrap script
curl -L https://raw.githubusercontent.com/uberbinge/dotnix/main/bootstrap.sh | bash

# 4. Sync configs from 1Password
cd ~/dev/dotnix && ./sync-config-files.sh
```

### Existing System Updates
```bash
# Apply configuration changes
hs  # or: darwin-rebuild switch --flake ~/dev/dotnix#default

# Update all packages
nix flake update && hs
```

## What's Included

- **Shell Environment**: zsh + Starship prompt, modern CLI tools
- **Editor**: Neovim with 40+ plugins, LSP, and productivity features  
- **System Config**: macOS preferences, Alfred workflows, SSH setup
- **Applications**: Development tools, productivity apps via Homebrew
- **Security**: 1Password SSH agent, secure credential management


## Structure

- `common/` - Shared configuration across platforms
- `darwin/` - macOS-specific settings and applications
- `linux/` - Linux/NixOS configurations
- `bootstrap.sh` - Automated setup script

Ready for development in minutes, not hours.