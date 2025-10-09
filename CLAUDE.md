# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

This repository contains a comprehensive multi-platform Nix configuration for managing development environments, applications, and system settings across macOS and Linux systems using Nix Flakes. It features advanced version control system (VCS) integration with both Git and Jujutsu (jj), extensive Alfred workflow automation, and secure credential management via 1Password.

## Repository Structure

```
flake.nix                 # Main flake with universal multi-platform system definitions
├── bootstrap.sh         # Idempotent MacBook setup script
├── sync-config-files.sh  # 1Password config file synchronization
├── POST-SETUP-APPS.md   # Post-installation manual app configuration guide
├── CLAUDE.local.md      # Local Claude-specific notes (gitignored)
├── common/               # Shared configuration across all platforms
│   ├── home.nix         # Core Home Manager config with shell setup
│   ├── nixvim.nix       # Comprehensive Neovim configuration with 40+ plugins
│   ├── vcs.nix          # Git & Jujutsu (jj) version control configuration
│   └── scripts.nix      # Custom shell scripts and utilities
├── darwin/              # macOS-specific configurations
│   ├── configuration.nix    # System-level macOS settings
│   ├── homebrew.nix         # GUI apps and Mac App Store apps
│   ├── defaults.nix         # macOS system preferences & keyboard shortcuts
│   ├── alfred.nix           # Alfred workflows and shortcuts
│   ├── home.nix            # macOS-specific home configuration
│   ├── alfred-workflows/    # Alfred workflow files (.alfredworkflow)
│   │   ├── website opener.alfredworkflow
│   │   ├── Gpt-Grammer.alfredworkflow
│   │   └── Hotkeys - Getting Started.alfredworkflow
│   └── alfred-icons/        # Custom icons for Alfred shortcuts
│       ├── brave.png
│       └── grafana.png
└── linux/               # Linux/NixOS configurations
    ├── configuration.nix  # Linux system configuration
    └── home.nix          # Linux-specific home configuration
```

## Common Commands

### System Building & Updating

#### macOS Commands
```bash
# Initial setup (one-time)
nix run nix-darwin -- switch --flake .

# Apply changes after modifying configuration
darwin-rebuild switch --flake ~/dev/dotnix

# Quick rebuild (uses alias 'hs' defined in shell)
hs

# Update packages to latest versions
nix flake update
darwin-rebuild switch --flake ~/dev/dotnix

# Update homebrew apps while preserving browser extensions
update-homebrew-apps
```

#### Linux/NixOS Commands
```bash
# Home Manager only (uses current user automatically)
home-manager switch --flake ~/dev/dotnix

# Full NixOS system (requires sudo)
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

# Quick project navigation (tmux-sessionizer)
# Bound to Ctrl+X in terminal
tmux-sessionizer
```

## Key Features

### Core Functionality
- **Universal Platform Support**: Single configuration works on any macOS/Linux machine
- **Declarative System Management**: Everything defined in code, reproducible across machines
- **Comprehensive Neovim Setup**: 40+ plugins with LSP, treesitter, and modern UI
- **Advanced Shell Environment**: Zsh with Starship prompt, Atuin history sync, modern CLI tools
- **Dual VCS Support**: Git and Jujutsu (jj) with extensive aliases and workflows
- **Custom Productivity Scripts**: Project navigation, cache management, automation tools
- **GitHub CLI Integration**: SSH-first configuration with automatic credential management
- **macOS Regional Settings**: Celsius, Metric, DD/MM/YYYY, Monday first day of week
- **Window Management**: Always prefer tabs when opening documents

### Version Control Systems

#### Git Configuration
- **SSH Signing with 1Password**: All commits automatically signed using 1Password SSH agent
- **Delta Integration**: Beautiful, syntax-highlighted diffs with side-by-side view
- **Git LFS Support**: Large file storage configured
- **Smart Aliases**: `gone` (cleanup merged branches), `visual` (gitk), `last` (recent commit)
- **Cross-platform Credential Helper**: osxkeychain on macOS, cache on Linux

#### Jujutsu (jj) VCS - Modern Git Alternative
Comprehensive workflow optimized for busy developers:

**Core Operations:**
- `js` - status check
- `jl` - one-line log with author, timestamp, bookmarks
- `jc [message]` - commit with optional inline message
- `jds [message]` - describe with optional inline message
- `jp` - push to remote
- `jn` - new revision
- `je` - edit revision
- `jd` - diff current changes
- `jr` - rebase

**Advanced Workflows:**
- `jstart [base-branch]` - Fetch, sync, cleanup merged bookmarks, start new work
- `jcp [message]` - Commit current work, detect bookmark, push automatically
- `jpr <branch> [message]` - Create branch, commit, push, auto-create draft PR
- `jmerge <parent1> <parent2>` - Merge two revisions

**Operation Management (Time Travel):**
- `jop` - operation log (undo history)
- `jun` - undo last operation
- `jor` - restore to specific operation

**Bookmark (Branch) Management:**
- `jbc`, `jbm`, `jbd`, `jbt` - create, move, delete, track bookmarks

**Log Views with Revsets:**
- `jlm` - Everything on main branch
- `jlme` - Main branch + current path
- `jlmine` - All your authored revisions
- `jlall` - Everything

### Custom Scripts & Workflows

#### Shell Scripts (common/scripts.nix)
- **`tmux-sessionizer`**: Quick project navigation tool (Ctrl+X binding)
- **`update_find_cache.sh`**: Maintains directory cache for fast project navigation
- **`sync-config-files.sh`**: Syncs AWS, NPM, Gradle configs from 1Password
- **`update-homebrew-apps`**: Updates homebrew packages while preserving browser extensions

#### Alfred Workflows (darwin/alfred-workflows/)
Pre-configured workflows stored in repository:
- **Website Opener**: Custom shortcuts for development sites (GitHub, Grafana, etc.)
- **GPT Grammar**: Grammar checking integration
- **Hotkeys**: Getting started guide

Custom icons stored in `darwin/alfred-icons/` for visual consistency.

### Modern Security & Environment Management
- **1Password Family Account**: All secrets in `Private` vault at `my.1password.eu`
- **1Password SSH Agent**: Git signing and SSH operations handled by 1Password (no manual keys)
- **Tailscale SSH**: Machine-to-machine access without manual key management
- **Config File Sync**: AWS, NPM, Gradle properties synced from 1Password on demand
- **Cross-platform SSH Signing**: Works identically on macOS and Linux
- **Automatic User Detection**: Username auto-detected from `$USER` or `FLAKE_USERNAME` env var
- **Touch ID for Sudo**: Enabled on macOS for convenient authentication
- **Environment Variables as Code**: API keys loaded via `op://` references in Nix

### Development Tools & Packages

#### Core Development
- `mise` - Runtime version manager (replaces asdf)
- `rustup` - Rust toolchain installer
- `gh` - GitHub CLI with automatic credential integration
- `lazygit` - Terminal UI for git operations
- `just` - Command runner (like make but better)
- `deno` - JavaScript/TypeScript runtime

#### Modern CLI Replacements
- `bat` → replaces `cat` (syntax highlighting)
- `eza` → replaces `ls` (modern, colored output)
- `fd` → replaces `find` (fast, user-friendly)
- `ripgrep` → replaces `grep` (fastest search)
- `delta` → enhances `git diff` (beautiful diffs)
- `zoxide` → enhances `cd` (smart directory jumping)

#### Cloud & DevOps
- `awscli` - AWS command line interface
- `aws-sso-cli` - AWS SSO authentication helper
- `helm` - Kubernetes package manager
- `docker` + `docker-compose` - Container management
- Podman wrappers (aliased to docker commands)

#### Productivity & Media
- `fzf` - Fuzzy finder for terminal
- `jq` - JSON processor
- `yt-dlp` - YouTube downloader
- `ncspot` - Spotify TUI client
- `atuin` - Enhanced shell history with sync

### Keyboard Shortcuts & System Integration
- **Spotlight Shortcuts Disabled**: Cmd+Space freed for Alfred (shortcuts 60, 64, 65 disabled)
- **GitHub CLI Integration**: Automatic git credential management
- **Touch ID for Sudo**: Enabled on macOS
- **Ctrl+X**: tmux-sessionizer (quick project navigation)
- **Ctrl+R**: Atuin enhanced history search

## Architecture Overview

This repository uses **Nix Flakes** for deterministic, reproducible system configurations. The architecture is designed for:
1. **Universal Configuration**: Single config works on any machine (hostname-agnostic)
2. **Username Flexibility**: Auto-detects username from environment (`FLAKE_USERNAME` or `$USER`)
3. **Modular Design**: Shared common config with platform-specific overrides
4. **Secure Secrets**: All credentials managed via 1Password, never committed to git

### Key Architectural Components

#### 1. Flake Inputs (`flake.nix`)
- `nixpkgs` - Main package repository (unstable channel)
- `nix-darwin` - macOS system configuration
- `home-manager` - User environment management
- `nix-homebrew` - Declarative Homebrew management
- `nixvim` - Neovim configuration as Nix module
- `website-opener` - Custom Alfred workflow helper

#### 2. Configuration Function (`mkConfiguration`)
Creates system configurations with these parameters:
- `system` - Target platform (aarch64-darwin, aarch64-linux, x86_64-linux)
- `username` - User account name (auto-detected)
- `hostname` - Optional hostname (not required for macOS)
- `isNixOS` - Boolean flag for full NixOS vs Home Manager only

#### 3. Special Args (Passed to All Modules)
```nix
specialArgs = {
  inherit system username hostname;
  githubUserEmail = "1692495+uberbinge@users.noreply.github.com";
  githubUserName = "uberbinge";
}
```

#### 4. Universal Darwin Configuration
```nix
darwinConfigurations.default = mkConfiguration {
  system = "aarch64-darwin";
  username = currentUsername;  # Auto-detected
  hostname = "mac";  # Generic, doesn't need to match actual hostname
};
```

Usage: `darwin-rebuild switch --flake .#default`

## Security Notes

### 1Password Integration
- **Account Type**: Family account at `my.1password.eu`
- **Vault**: All secrets stored in `Private` vault
- **SSH Agent**: Handles all SSH operations (no manual key files)
- **Git Signing**: Commits signed using SSH key from 1Password
- **Environment Variables**: Loaded via `op://Private/<item>/notesPlain` syntax
- **Config Files**: AWS, NPM, Gradle properties synced on-demand

### Git Commit Signing
```nix
user.signingkey = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCvxBgc...";
gpg.format = "ssh";
gpg."ssh".program = "/Applications/1Password.app/Contents/MacOS/op-ssh-sign";  # macOS
# or: "${pkgs._1password-gui}/bin/op-ssh-sign"  # Linux
commit.gpgsign = true;
```

### Touch ID for Sudo (macOS)
Enabled in `darwin/configuration.nix` for convenient authentication without typing password.

### No Manual Key Management
- SSH keys: 1Password SSH Agent
- Git signing: 1Password SSH Agent  
- Machine-to-machine: Tailscale SSH
- API keys: 1Password `op://` references

## Configuration Areas

### System Preferences (darwin/defaults.nix)

#### Regional & Format Settings
- **Temperature**: Celsius
- **Measurement**: Metric system
- **Date Format**: DD/MM/YYYY
- **Number Format**: 1,234,567.89 (comma thousand separator)
- **First Day of Week**: Monday
- **Clock**: 24-hour format

#### Window Management
- **Tab Preference**: Always prefer tabs when opening documents
- **Window Behavior**: Consistent tabbed interface across apps

#### Keyboard Shortcuts
- **Spotlight Disabled**: Shortcuts 60, 64, 65 disabled to free Cmd+Space
- **Alfred Ready**: Cmd+Space available for Alfred configuration
- **Touch ID**: Enabled for sudo authentication

### Development Environment (common/home.nix)

#### Shell Configuration
- **Shell**: Zsh with extensive customization
- **Prompt**: Starship (fast, customizable, multi-language support)
- **History**: Atuin with cloud sync capability
- **Directory Navigation**: zoxide (smart `cd` replacement)
- **Multiplexer**: tmux with custom sessionizer (Ctrl+X)

#### GitHub CLI (gh)
```bash
gh config set git_protocol ssh      # Always use SSH
gh config set editor nvim           # Use Neovim for editing
gh auth login                       # Automatic credential helper setup
```

#### Environment Variables (1Password Integration)
```nix
sessionVariables = {
  EDITOR = "nvim";
  TELEGRAM_BOT = "op://Private/telegram-bot/notesPlain";
  TELEGRAM_CHAT_ID = "op://Private/telegram-chat-id/notesPlain";
  BRAVE_API_KEY = "op://Private/brave-api-key/notesPlain";
  TEST_USER = "op://Private/test-user/notesPlain";
};
```

### Version Control Systems (common/vcs.nix)

#### Git Features
- **SSH Signing**: Every commit automatically signed
- **Delta Diff Viewer**: Syntax highlighting, side-by-side diffs, line numbers
- **LFS Support**: Large file storage configured
- **Auto Remote Tracking**: `push.autoSetupRemote = true`
- **Diff3 Merge Style**: Better conflict resolution with common ancestor
- **Color-moved Detection**: Highlights moved code blocks

#### Jujutsu (jj) Features
- **Auto Local Bookmarks**: Git branches automatically become jj bookmarks
- **Delta Integration**: Same beautiful diffs as git
- **Custom Templates**: One-line log format with author, timestamp, change ID
- **Smart Workflows**: Functions for common operations (start, commit+push, PR creation)
- **Time Travel**: Full operation log with undo/restore capabilities

### Alfred Integration (darwin/alfred.nix)

#### Installed Workflows
- **Website Opener**: Quick access to development sites and tools
- **GPT Grammar**: Grammar checking integration
- **Hotkeys**: Getting started workflow

#### Custom Icons
Icons stored in `darwin/alfred-icons/` for consistent visual branding:
- `brave.png` - Brave browser shortcuts
- `grafana.png` - Grafana dashboard links

### Homebrew Management (darwin/homebrew.nix)

#### Cask Applications (GUI Apps)
- **Productivity**: Alfred, Caffeine, Obsidian, Raycast, DeepL
- **Development**: JetBrains Toolbox, Docker, Ghostty terminal
- **Communication**: Beeper, Slack, Discord
- **Utilities**: Lunar (display management), Ice (menu bar management), Choosy (browser picker)

#### Brew Formulas (CLI Tools)
- **AWS**: awscli, aws-sso-cli
- **DevOps**: helm, just, scrcpy
- **Productivity**: mise, pandoc
- **Security**: gnupg

#### Mac App Store Apps (via mas)
Managed declaratively through homebrew configuration.

## Post-Installation Setup

See `POST-SETUP-APPS.md` for comprehensive post-installation guide covering:
- **Security**: 1Password SSH agent, Tailscale VPN
- **Development**: Atuin sync, GitHub CLI auth, AWS configuration
- **Productivity**: Alfred license and workflows, browser sign-ins
- **Verification**: Checklist to ensure everything works

## Common Workflows

### Daily Development
```bash
# Start your day
jstart main              # Fetch latest, clean up, start new work

# Make changes, commit, and push
jcp "Add new feature"    # Auto-detects branch, commits, pushes

# Create a PR
jpr feat-branch "New feature description"  # Creates branch, commits, pushes, opens draft PR

# Quick project switching
# Press Ctrl+X, type project name, hit enter

# Rebuild system after config changes
hs                       # Alias for darwin-rebuild switch
```

### Git vs Jujutsu Decision Matrix
- **Use Git when**: Working with teams unfamiliar with jj, existing repos with complex history
- **Use Jujutsu when**: Personal projects, experimental work, need powerful undo, want better UX

Both are fully configured and ready to use. Jujutsu can work with Git repos seamlessly.

## Troubleshooting

### "Command not found" after rebuild
```bash
source ~/.zshrc          # Reload shell environment
# or just restart terminal
```

### 1Password SSH agent not working
```bash
ssh-add -l               # Should list your 1Password keys
# If empty, check 1Password Settings → Developer → SSH agent is enabled
```

### Darwin rebuild fails
```bash
# Check for syntax errors
nix flake check

# Format all nix files
nix run nixpkgs#nixpkgs-fmt -- .

# Try with more verbose output
darwin-rebuild switch --flake ~/dev/dotnix --show-trace
```

### Jujutsu workflow questions
```bash
jop                      # Show operation history (your safety net)
jun                      # Undo last operation if something went wrong
jj help                  # Built-in help system
```

## Development & Contribution

### Formatting
This repository uses `nixpkgs-fmt` for consistent Nix formatting:
```bash
nix develop              # Enter dev shell with formatting tools
nixpkgs-fmt --check .    # Check formatting
nixpkgs-fmt .            # Auto-format all files
```

### Testing Changes
1. Make changes to configuration files
2. Run `darwin-rebuild switch --flake ~/dev/dotnix` (or `hs` alias)
3. Test the changes
4. If something breaks, the previous generation is still available in System Preferences → Profiles

### Adding New Packages
- **CLI tools**: Add to `common/home.nix` packages list
- **macOS GUI apps**: Add to `darwin/homebrew.nix` casks
- **System config**: Modify appropriate platform-specific configuration.nix

## Philosophy & Design Principles

1. **Declarative Over Imperative**: Everything defined in code, no manual steps
2. **Universal Over Specific**: Single config works on any machine
3. **Secure by Default**: All secrets in 1Password, never in git
4. **Modern Tools**: Prefer better alternatives (bat > cat, eza > ls, jj > git for new work)
5. **Developer Experience**: Optimize for productivity (aliases, shortcuts, automation)
6. **Cross-platform**: Maximize code sharing between macOS and Linux
7. **Reproducible**: Anyone can recreate this setup from scratch using bootstrap.sh