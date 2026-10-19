# darwin/work/homebrew.nix
# Development Mac apps shared by work, macbook, and mac-personal.
{ ... }:
{
  homebrew = {
    casks = [
      # Productivity (work-specific)
      "caffeine"
      "lunar"

      # Communication (work requires these)
      "discord"
      "slack"
      "telegram"
      "signal"
      "microsoft-teams"
      "microsoft-outlook"

      # Browsers (need multiple for testing)
      "brave-browser"
      "firefox"
      "google-chrome"
      "microsoft-edge"
      "zen"

      # Development (work-specific)
      "zed"
    ];
  };
}
