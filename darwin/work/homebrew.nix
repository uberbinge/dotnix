# darwin/work/homebrew.nix
# Work Mac specific Homebrew apps
{ pkgs, lib, ... }:
{
  homebrew = {
    brews = [
      "mise"

      # Development tools
      "aws-sso-cli"
      "awscli"
      "just"
      "helm"
      "scrcpy"

      # System tools
      "pandoc"
      "gnupg"
      "gemini-cli"

      # AI tools
      "charmbracelet/tap/crush"
    ];

    casks = [
      # Productivity
      "alfred"
      "caffeine"
      "raycast"
      "lunar"
      "jordanbaird-ice"
      "choosy"
      "obsidian"
      "beeper"

      # Security & Virtualization
      "nordvpn"
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
      "zen"

      # Development Tools
      "zed"
      "cursor"
      "orbstack"
      "chatgpt"
      "visual-studio-code"
      "android-platform-tools"
      "figma"
      "miro"
      "codex"
    ];
  };
}
