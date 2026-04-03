# darwin/work/homebrew.nix
# Work Mac ONLY - apps not needed on other machines
{ ... }:
{
  homebrew = {
    brews = [
      # Build & deployment
      "just"
      "helm"

      # Document processing
      "pandoc"
      "gnupg"

      # Development tools
      "firebase-cli"
      "supabase"
      "anomalyco/tap/opencode"
    ];

    taps = [
      "anomalyco/tap"
    ];

    casks = [
      # Productivity (work-specific)
      "caffeine"
      "lunar"
      # Virtualization & enterprise
      "jetbrains-toolbox"

      # Communication (work requires these)
      "discord"
      "slack"
      "telegram"
      "signal"
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
