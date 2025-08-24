#!/usr/bin/env bash
set -e

# ==============================================================================
# 🚀 Consolidated Idempotent MacBook Bootstrap Script
# ==============================================================================
# This script can be run multiple times safely without negative effects.
# It handles fresh installs and updates existing installations.
#
# USAGE:
#   # New Mac:
#   curl -L https://raw.githubusercontent.com/uberbinge/dotnix/main/bootstrap.sh | bash
#   
#   # Or locally:
#   ./bootstrap.sh
#
#   # With options:
#   ./bootstrap.sh --skip-xcode    # Skip Xcode tools check
#   ./bootstrap.sh --force         # Force reinstall components
#   ./bootstrap.sh --dry-run       # Show what would be done
#
#   # Note: For config files, run ./sync-config-files.sh after bootstrap
# ==============================================================================

# Script configuration
SCRIPT_VERSION="2.2.0"
CURRENT_USER=$(whoami)  # Automatically detect current user
WORK_DIR="$HOME/dev"
CONFIG_DIR="$WORK_DIR/dotnix"
REPO_URL="https://github.com/uberbinge/dotnix.git"
REPO_SSH="git@github.com:uberbinge/dotnix.git"

# Colors and formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m' # No Color

# Prevent running as root to avoid permission issues
if [ "$EUID" -eq 0 ]; then
    echo -e "${RED}❌ Error: Do not run this script as root or with sudo${NC}"
    echo -e "${YELLOW}💡 Run as regular user: ./bootstrap.sh${NC}"
    echo -e "${DIM}   (sudo will be used automatically when needed for system changes)${NC}"
    exit 1
fi

# Command line options
SKIP_XCODE=false
FORCE_INSTALL=false
DRY_RUN=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-xcode)
            SKIP_XCODE=true
            shift
            ;;
        --force)
            FORCE_INSTALL=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --skip-xcode    Skip Xcode Command Line Tools installation"
            echo "  --force         Force reinstall components"
            echo "  --dry-run       Show what would be done without executing"
            echo "  -h, --help      Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# ==============================================================================
# UTILITY FUNCTIONS
# ==============================================================================

log() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
}

step() {
    echo -e "\n${BOLD}${YELLOW}$1${NC}"
    echo -e "${DIM}$(printf '%.0s-' {1..50})${NC}"
}

check_command() {
    command -v "$1" >/dev/null 2>&1
}

# Execute command unless in dry-run mode
execute() {
    if [ "$DRY_RUN" = true ]; then
        echo -e "${DIM}[DRY RUN] Would execute: $*${NC}"
        return 0
    fi
    "$@"
}

# Check if component already exists/installed
is_installed() {
    case $1 in
        "xcode")
            xcode-select -p >/dev/null 2>&1
            ;;
        "nix")
            [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ] && check_command nix
            ;;
        "nix-darwin")
            check_command darwin-rebuild
            ;;
        "homebrew")
            check_command brew
            ;;
        "ssh-keys")
            [ -f "$HOME/.ssh/id_ed25519" ] || [ -f "$HOME/.ssh/id_rsa" ]
            ;;
        "config-repo")
            [ -d "$CONFIG_DIR/.git" ]
            ;;
        *)
            return 1
            ;;
    esac
}

# ==============================================================================
# MAIN BOOTSTRAP PHASES
# ==============================================================================

show_header() {
    clear
    echo -e "${BOLD}${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                    🚀 MacBook Bootstrap Script v$SCRIPT_VERSION                    ║"
    echo "║                                                                              ║"
    echo "║  🧑‍💻 User: $CURRENT_USER"
    printf "║%*s║\n" $((73 - ${#CURRENT_USER})) ""
    echo "║  This script will set up your complete development environment:             ║"
    echo "║  • Xcode Command Line Tools                                                 ║"
    echo "║  • SSH via Tailscale + 1Password SSH Agent                                  ║"
    echo "║  • Nix Package Manager + Darwin                                             ║"
    echo "║  • Complete System Configuration                                            ║"
    echo "║  • 50+ Applications via Homebrew                                            ║"
    echo "║  • Shell History (Atuin) Setup                                              ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    if [ "$DRY_RUN" = true ]; then
        warning "DRY RUN MODE - No changes will be made"
    fi
    
    if [ "$FORCE_INSTALL" = true ]; then
        warning "FORCE MODE - Will reinstall existing components"
    fi
    
    echo ""
}

check_prerequisites() {
    step "🔍 Checking Prerequisites"
    
    # Check macOS version
    MACOS_VERSION=$(sw_vers -productVersion)
    log "macOS Version: $MACOS_VERSION"
    
    # Check architecture
    ARCH=$(uname -m)
    log "Architecture: $ARCH"
    
    # Check available disk space
    AVAILABLE_SPACE=$(df -h / | awk 'NR==2{print $4}')
    log "Available disk space: $AVAILABLE_SPACE"
    
    # Check if we have internet
    if ! ping -c 1 google.com >/dev/null 2>&1; then
        error "No internet connection detected"
        exit 1
    fi
    success "Internet connection verified"
    
    # Add common homebrew paths for tools
    export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
}

install_xcode_tools() {
    step "🔨 Xcode Command Line Tools"
    
    if [ "$SKIP_XCODE" = true ]; then
        warning "Skipping Xcode tools installation (--skip-xcode)"
        return 0
    fi
    
    if is_installed "xcode" && [ "$FORCE_INSTALL" != true ]; then
        success "Xcode Command Line Tools already installed"
        return 0
    fi
    
    if ! check_command git; then
        log "Installing Xcode Command Line Tools..."
        if [ "$DRY_RUN" != true ]; then
            xcode-select --install
            echo "Waiting for Xcode installation to complete..."
            echo "Press Enter when installation is finished..."
            read -p ""
        fi
    fi
    
    if is_installed "xcode"; then
        success "Xcode Command Line Tools installed"
    else
        error "Xcode Command Line Tools installation failed"
        exit 1
    fi
}


install_nix() {
    step "❄️  Nix Package Manager"
    
    if is_installed "nix" && [ "$FORCE_INSTALL" != true ]; then
        success "Nix already installed"
        # Source Nix environment
        if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
            . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
        fi
        return 0
    fi
    
    if [ "$FORCE_INSTALL" = true ]; then
        warning "Force reinstalling Nix..."
    fi
    
    log "Installing Nix..."
    if [ "$DRY_RUN" != true ]; then
        curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
        
        # Source Nix environment for current session
        if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
            . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
            success "Nix environment loaded"
        fi
    fi
    
    # Enable flakes (idempotent)
    execute mkdir -p ~/.config/nix
    if ! grep -q "experimental-features" ~/.config/nix/nix.conf 2>/dev/null; then
        if [ "$DRY_RUN" != true ]; then
            echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
        fi
        success "Nix flakes enabled"
    else
        success "Nix flakes already enabled"
    fi
    
    if is_installed "nix"; then
        success "Nix installation completed"
    else
        error "Nix installation failed"
        exit 1
    fi
}

clone_configuration() {
    step "📦 Configuration Repository"
    
    # Create work directory structure
    execute mkdir -p "$WORK_DIR"
    
    if is_installed "config-repo" && [ "$FORCE_INSTALL" != true ]; then
        success "Configuration repository already exists"
        log "Updating configuration..."
        if [ "$DRY_RUN" != true ]; then
            cd "$CONFIG_DIR"
            git pull origin main 2>/dev/null || git pull origin master 2>/dev/null || true
        fi
        return 0
    fi
    
    if [ -d "$CONFIG_DIR" ] && [ "$FORCE_INSTALL" = true ]; then
        warning "Removing existing configuration for fresh clone..."
        execute rm -rf "$CONFIG_DIR"
    fi
    
    if [ ! -d "$CONFIG_DIR" ]; then
        log "Cloning configuration repository..."
        
        # Try SSH first, fall back to HTTPS
        CLONE_SUCCESS=false
        if [ "$DRY_RUN" != true ]; then
            if git clone "$REPO_SSH" "$CONFIG_DIR" 2>/dev/null; then
                CLONE_SUCCESS=true
                log "Cloned via SSH"
            fi
        fi
        
        if [ "$CLONE_SUCCESS" != true ] && [ "$DRY_RUN" != true ]; then
            log "Trying HTTPS clone..."
            if git clone "$REPO_URL" "$CONFIG_DIR"; then
                CLONE_SUCCESS=true
                log "Cloned via HTTPS"
            fi
        fi
        
        if [ "$DRY_RUN" = true ] || [ "$CLONE_SUCCESS" = true ]; then
            success "Configuration repository cloned"
        else
            error "Failed to clone configuration repository"
            exit 1
        fi
    fi
}

install_nix_darwin() {
    step "🍎 Nix-Darwin System Configuration"
    
    if ! [ -d "$CONFIG_DIR" ]; then
        error "Configuration directory not found at $CONFIG_DIR"
        exit 1
    fi
    
    cd "$CONFIG_DIR"
    
    # Check if nix-darwin is already installed
    if is_installed "nix-darwin" && [ "$FORCE_INSTALL" != true ]; then
        log "Nix-Darwin already installed, running system update..."
        log "Using current user: $CURRENT_USER"
        if [ "$DRY_RUN" != true ]; then
            FLAKE_USERNAME="$CURRENT_USER" sudo -E darwin-rebuild switch --flake .#default
        fi
        success "System configuration updated"
        return 0
    fi
    
    log "Installing Nix-Darwin system configuration..."
    log "Using current user: $CURRENT_USER"
    log "This may take 10-15 minutes on first run..."
    
    if [ "$DRY_RUN" != true ]; then
        FLAKE_USERNAME="$CURRENT_USER" sudo -E nix run nix-darwin -- switch --flake .#default
    fi
    
    success "Nix-Darwin system configuration completed"
}

setup_environment() {
    step "🔄 Environment Setup"
    
    log "Environment variables: Managed by Nix home.sessionVariables"
    log "Config files: Run './sync-config-files.sh' to sync from 1Password"
    
    # Note about optional setup
    log "Optional: Set up Atuin history sync manually after bootstrap:"
    log "  atuin register  # or: atuin login"
    log "  atuin sync"
}

show_completion() {
    step "🎉 Bootstrap Complete!"
    
    echo -e "${GREEN}"
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                          ✅ Setup Completed Successfully!                    ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    echo -e "${BOLD}What was installed:${NC}"
    echo "  ✅ Complete development environment"
    echo "  ✅ 50+ applications via Homebrew" 
    echo "  ✅ System preferences and shortcuts"
    echo "  ✅ Environment variables configured (Gradle, API keys)"
    echo "  ✅ Modern SSH setup instructions"
    echo ""
    
    echo -e "${BOLD}Next steps:${NC}"
    echo "  1. Set up config files: ./sync-config-files.sh"
    echo "  2. Set up 1Password SSH Agent:"
    echo "     • Open 1Password → Settings → Developer → Enable SSH agent"
    echo "     • Add your SSH key as an SSH Key item in 1Password"
    echo "  3. Restart your terminal or run: source ~/.zshrc"
    echo "  4. Test the environment: hs (should rebuild system)"
    echo "  5. For app-specific setup, see: ~/dev/dotnix/POST-SETUP-APPS.md"
    echo ""
    
    echo -e "${BOLD}Quick verification:${NC}"
    echo "  • Test tmux sessionizer: Ctrl+X"
    echo "  • Test shell history: Ctrl+R"
    echo "  • Test git access: git status (in any repo)"
    echo "  • Test development tools: node --version, aws --version"
    echo ""
    
    if [ "$DRY_RUN" = true ]; then
        warning "This was a DRY RUN - no actual changes were made"
        echo "Run without --dry-run to perform the actual installation"
    fi
    
    success "Your MacBook is ready for development! 🚀"
}

# ==============================================================================
# MAIN EXECUTION
# ==============================================================================

main() {
    show_header
    
    # Always run these checks
    check_prerequisites
    
    # Installation phases
    install_xcode_tools
    install_nix
    clone_configuration
    install_nix_darwin
    setup_environment
    
    show_completion
}

# Handle script interruption
trap 'echo -e "\n${RED}❌ Script interrupted by user${NC}"; exit 1' INT TERM

# Run main function
main "$@"