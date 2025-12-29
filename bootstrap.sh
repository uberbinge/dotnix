#!/usr/bin/env bash
set -e

# ==============================================================================
# 🚀 Multi-Machine Idempotent Mac Bootstrap Script
# ==============================================================================
# This script can be run multiple times safely without negative effects.
# It handles fresh installs and updates existing installations.
#
# SUPPORTED MACHINES:
#   work  - Work MacBook (development machine)
#   mini  - Mac Mini (media server with Jellyfin, Immich, Paperless, etc.)
#
# USAGE:
#   # New Mac (auto-detects machine type based on username):
#   curl -L https://raw.githubusercontent.com/uberbinge/dotnix/main/bootstrap.sh | bash
#
#   # Specify machine type explicitly:
#   ./bootstrap.sh --machine work
#   ./bootstrap.sh --machine mini
#
#   # Other options:
#   ./bootstrap.sh --dry-run       # Show what would be done
#   ./bootstrap.sh --force         # Force reinstall components
# ==============================================================================

# Script configuration
SCRIPT_VERSION="3.0.0"
CURRENT_USER=$(whoami)  # Automatically detect current user
WORK_DIR="$HOME/dev"
CONFIG_DIR="$WORK_DIR/dotnix"
REPO_URL="https://github.com/uberbinge/dotnix.git"
REPO_SSH="git@github.com:uberbinge/dotnix.git"

# Machine type (work or mini) - auto-detected or specified via flag
MACHINE_TYPE=""

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

# Check Xcode prerequisites before starting (called early in main)
check_xcode_prerequisites() {
    echo -e "${BLUE}🔍 Checking Prerequisites${NC}"
    echo -e "${DIM}──────────────────────────────────────────────────────────────────────${NC}"

    # Check for Xcode Command Line Tools
    if ! command -v git >/dev/null 2>&1 || ! command -v make >/dev/null 2>&1; then
        echo -e "${RED}❌ Xcode Command Line Tools not found${NC}"
        echo -e "${YELLOW}📋 MANUAL SETUP REQUIRED:${NC}"
        echo -e ""
        echo -e "${BOLD}1. Install Xcode Command Line Tools:${NC}"
        echo -e "   ${DIM}sudo xcode-select --install${NC}"
        echo -e ""
        echo -e "${BOLD}2. Wait for installation to complete (may take 5-15 minutes)${NC}"
        echo -e ""
        echo -e "${BOLD}3. Verify installation:${NC}"
        echo -e "   ${DIM}git --version${NC}"
        echo -e "   ${DIM}make --version${NC}"
        echo -e ""
        echo -e "${BOLD}4. Re-run this script:${NC}"
        echo -e "   ${DIM}curl -L https://raw.githubusercontent.com/uberbinge/dotnix/main/bootstrap.sh | bash${NC}"
        echo -e ""
        echo -e "${DIM}💡 Xcode Command Line Tools must be installed manually due to macOS security restrictions${NC}"
        exit 1
    fi

    success "Xcode Command Line Tools found"
}

# Command line options
SKIP_XCODE=false
FORCE_INSTALL=false
DRY_RUN=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --machine)
            MACHINE_TYPE="$2"
            if [[ "$MACHINE_TYPE" != "work" && "$MACHINE_TYPE" != "mini" ]]; then
                echo "Error: --machine must be 'work' or 'mini'"
                exit 1
            fi
            shift 2
            ;;
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
            echo "  --machine TYPE  Machine type: 'work' or 'mini' (auto-detected if not specified)"
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
# MACHINE DETECTION
# ==============================================================================

detect_machine_type() {
    # If already specified via flag, use that
    if [ -n "$MACHINE_TYPE" ]; then
        return 0
    fi

    # Auto-detect based on username (more stable than hostname)
    # Username is set at account creation and rarely changes
    if [ "$CURRENT_USER" = "waqas" ]; then
        MACHINE_TYPE="mini"
        log "Auto-detected machine type: mini (based on username)"
        return 0
    else
        # Default to work for any other username (including waqas.ahmed)
        MACHINE_TYPE="work"
        log "Auto-detected machine type: work (based on username)"
        return 0
    fi
}

# ==============================================================================
# MAIN BOOTSTRAP PHASES
# ==============================================================================

show_header() {
    clear
    echo -e "${BOLD}${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                    🚀 Mac Bootstrap Script v$SCRIPT_VERSION                        ║"
    echo "║                                                                              ║"
    echo "║  🧑‍💻 User: $CURRENT_USER"
    printf "║%*s║\n" $((73 - ${#CURRENT_USER})) ""
    echo "║  Supported machines:                                                        ║"
    echo "║  • work - Work MacBook (development environment)                            ║"
    echo "║  • mini - Mac Mini (media server + services)                                ║"
    echo "║                                                                              ║"
    echo "║  This script will set up:                                                   ║"
    echo "║  • Lix (Nix fork) + nix-darwin                                              ║"
    echo "║  • Applications via Homebrew                                                ║"
    echo "║  • System preferences and shell environment                                 ║"
    echo "║  • 1Password SSH Agent integration                                          ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    if [ "$DRY_RUN" = true ]; then
        warning "DRY RUN MODE - No changes will be made"
    fi

    if [ "$FORCE_INSTALL" = true ]; then
        warning "FORCE MODE - Will reinstall existing components"
    fi

    if [ -n "$MACHINE_TYPE" ]; then
        log "Machine type: $MACHINE_TYPE (from --machine flag)"
    fi

    echo ""
}

check_system_requirements() {
    step "🔍 Checking System Requirements"

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



install_nix() {
    step "❄️  Lix (Nix Fork)"

    if is_installed "nix" && [ "$FORCE_INSTALL" != true ]; then
        success "Nix/Lix already installed"
        # Source Nix environment
        if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
            . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
        fi
        return 0
    fi

    if [ "$FORCE_INSTALL" = true ]; then
        warning "Force reinstalling Lix..."
    fi

    log "Installing Lix (community Nix fork with better UX)..."
    if [ "$DRY_RUN" != true ]; then
        curl -sSf -L https://install.lix.systems/lix | sh -s -- install

        # Source Nix environment for current session
        if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
            . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
            success "Lix environment loaded"
        fi
    fi

    # Flakes are enabled by default in Lix, but ensure config exists
    execute mkdir -p ~/.config/nix
    if ! grep -q "experimental-features" ~/.config/nix/nix.conf 2>/dev/null; then
        if [ "$DRY_RUN" != true ]; then
            echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
        fi
        success "Flakes configuration added"
    else
        success "Flakes already configured"
    fi

    if is_installed "nix"; then
        success "Lix installation completed"
    else
        error "Lix installation failed"
        exit 1
    fi
}

clone_configuration() {
    step "📦 Configuration Repository"

    # Create work directory structure
    execute mkdir -p "$WORK_DIR"

    # Create config directories for 1Password integration
    execute mkdir -p ~/.config/alfred

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

    log "Machine type: $MACHINE_TYPE"
    log "Flake target: .#$MACHINE_TYPE"

    # Check if nix-darwin is already installed
    if is_installed "nix-darwin" && [ "$FORCE_INSTALL" != true ]; then
        log "Nix-Darwin already installed, running system update..."
        log "Using current user: $CURRENT_USER"
        if [ "$DRY_RUN" != true ]; then
            sudo darwin-rebuild switch --flake ".#$MACHINE_TYPE"
        fi
        success "System configuration updated"
        return 0
    fi

    log "Installing Nix-Darwin system configuration..."
    log "Using current user: $CURRENT_USER"
    log "This may take 10-15 minutes on first run..."

    if [ "$DRY_RUN" != true ]; then
        sudo nix run nix-darwin -- switch --flake ".#$MACHINE_TYPE"
    fi

    success "Nix-Darwin system configuration completed"
}

setup_environment() {
    step "🔄 Environment Setup"

    log "Environment variables: Managed by Nix home.sessionVariables"

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

    echo -e "${BOLD}Machine type: $MACHINE_TYPE${NC}"
    echo ""

    echo -e "${BOLD}What was installed:${NC}"
    echo "  ✅ Complete development environment"
    echo "  ✅ Applications via Homebrew"
    echo "  ✅ System preferences and shortcuts"
    echo "  ✅ Modern SSH setup (1Password SSH Agent)"

    if [ "$MACHINE_TYPE" = "mini" ]; then
        echo "  ✅ Media server services (Jellyfin, Immich, Paperless, Home Assistant)"
        echo "  ✅ Backup system (Borgmatic → Hetzner Storage Box)"
        echo "  ✅ Reverse proxy (Caddy)"
    fi
    echo ""

    echo -e "${BOLD}Next steps:${NC}"
    echo "  1. Set up 1Password SSH Agent:"
    echo "     • Open 1Password → Settings → Developer → Enable SSH agent"
    echo "  2. Restart your terminal or run: source ~/.zshrc"

    if [ "$MACHINE_TYPE" = "mini" ]; then
        echo "  3. Start media services:"
        echo "     • jellyfin-start"
        echo "     • immich-start"
        echo "     • paperless-start"
        echo "     • ha-start"
        echo "     • borgmatic-start"
        echo "  4. Verify services: docker ps"
        echo "  5. Access services:"
        echo "     • Jellyfin:       http://localhost:8096"
        echo "     • Immich:         http://localhost:2283"
        echo "     • Paperless:      http://localhost:8000"
        echo "     • Home Assistant: http://localhost:8123"
    else
        echo "  3. Test the environment: hs (should rebuild system)"
        echo "  4. For app-specific setup, see: ~/dev/dotnix/POST-SETUP-APPS.md"
    fi
    echo ""

    echo -e "${BOLD}Quick verification:${NC}"
    echo "  • Test shell history: Ctrl+R"
    echo "  • Test git access: git status (in any repo)"
    if [ "$MACHINE_TYPE" = "work" ]; then
        echo "  • Test tmux sessionizer: Ctrl+X"
        echo "  • Test development tools: node --version, aws --version"
    fi
    echo ""

    if [ "$DRY_RUN" = true ]; then
        warning "This was a DRY RUN - no actual changes were made"
        echo "Run without --dry-run to perform the actual installation"
    fi

    success "Your Mac is ready! 🚀"
}

# ==============================================================================
# MAIN EXECUTION
# ==============================================================================

main() {
    # Check Xcode tools first (before showing header)
    check_xcode_prerequisites

    show_header

    # Check system requirements (macOS version, disk space, internet)
    check_system_requirements

    # Detect or select machine type
    detect_machine_type

    # Installation phases
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
