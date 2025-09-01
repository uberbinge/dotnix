{ pkgs, lib, ... }:
{
  homebrew = {
    enable = true;
    onActivation = {
      cleanup = "none";
      upgrade = true;
    };
    global = {
      brewfile = true;
      lockfiles = true;
    };
    # Remove all taps - no longer needed (fonts moved to main repo)
    taps = [
      # "homebrew/cask-fonts" - REMOVED (fonts now in main cask repo)
    ];
    brews = [
      "mas" # Mac App Store CLI
      "mise"
      
      # Development tools
      "aws-sso-cli"  # AWS SSO authentication
      "awscli"       # AWS command line interface
      "just"         # Command runner
      "helm"         # Kubernetes package manager
      "scrcpy"       # Android screen mirroring
      
      # System tools
      "pandoc"       # Universal document converter
      "gnupg"        # GNU Privacy Guard
      "gemini-cli"   # Gemini protocol client
      
      # MANUAL INSTALLS (keep in Brewfile):
      # - usage: CLI usage statistics (niche tool)
      # - ffmpeg + codecs: Video processing (complex dependency tree)
    ];
    casks = [
      # Core productivity (existing)
      "alfred"
      "caffeine"
      "ghostty@tip"
      "raycast"
      "lunar"
      "bartender"
      "choosy"
      "deepl"
      "obsidian"
      "beeper"
      
      # Security & Virtualization
      "1password"
      "1password-cli"
      "nordvpn"
      "tailscale"
      "parallels"
      "jetbrains-toolbox"
      
      # Communication Apps
      "discord"
      "slack"
      "telegram"
      "signal"
      "whatsapp"
      "microsoft-teams"
      "microsoft-outlook"
      
      # Browsers
      "arc"
      "brave-browser"
      "firefox"
      "google-chrome"
      "microsoft-edge"
      "zen-browser"
      
      # Development Tools
      "zed"
      "orbstack"
      "chatgpt"
      "visual-studio-code"
      "android-platform-tools"
      "figma"
      "miro"
      
      # Fonts (managed by Nix fonts/ directory)
      "font-fira-code-nerd-font"
      
      # MANUAL INSTALLS (keep in Brewfile):
    ];
    masApps = {
      # Productivity & System
      "Magnet" = 441258766;                    # Window manager
      "AdBlock Pro" = 1018301773;              # Safari ad blocker
      "Drafts" = 1435957248;                   # Quick note capture
      
      # Reading & Research
      "Kindle" = 302584613;                    # Amazon e-book reader
      "Instapaper" = 288545208;                # Read-later service
      "Obsidian Web Clipper" = 6720708363;    # Web clipper for Obsidian
      
      # Smart Home & Security
      "Home Assistant" = 1099568401;           # Smart home control
      "Okta Verify" = 490179405;               # 2FA authentication
    };
  };
}
