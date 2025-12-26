# darwin/work/homebrew.nix
# Work Mac ONLY - apps not needed on other machines
{ ... }:
{
  homebrew = {
    brews = [
      # Build & deployment
      "just"
      "helm"
      "scrcpy"

      # Document processing
      "pandoc"
      "gnupg"
    ];

    casks = [
      # Productivity (work-specific)
      "caffeine"
      "raycast"
      "lunar"
      "jordanbaird-ice"
      "beeper"

      # Virtualization & enterprise
      "parallels"
      "jetbrains-toolbox"

      # Communication (work requires these)
      "discord"
      "slack"
      "telegram"
      "signal"
      "whatsapp"
      "microsoft-teams"
      "microsoft-outlook"

      # Browsers (need multiple for testing)
      "arc"
      "brave-browser"
      "firefox"
      "google-chrome"
      "microsoft-edge"
      "zen"

      # Development (work-specific)
      "zed"
      "android-platform-tools"
      "figma"
      "miro"
    ];
  };
}
