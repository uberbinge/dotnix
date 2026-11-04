# darwin/work/homebrew.nix
# Development Mac apps shared by work and macbook.
{ ... }:
{
  homebrew = {
    brews = [
      "just"
      "helm"
      "pandoc"
      "gnupg"
      "supabase"
    ];
    casks = [
      # Desktop Claude and the ChatGPT app containing Codex. Their CLIs have
      # separate native owners via the repo's per-tool mise tasks.
      "claude"
      "chatgpt"

      # Productivity (work-specific)
      "caffeine"
      "granola"
      "handy"
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
