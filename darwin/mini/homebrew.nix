# darwin/mini/homebrew.nix
# Mac Mini media server specific Homebrew apps
{ pkgs, lib, ... }:
{
  homebrew = {
    taps = [
      "charmbracelet/tap"
    ];

    brews = [
      # Development tools
      "mise"
      "aws-sso-cli"
      "awscli"

      # AI tools
      "gemini-cli"
      "crush" # charmbracelet/tap
    ];

    casks = [
      # Container runtime for media services
      "orbstack"

      # Development (for remote editing)
      "cursor"
      "visual-studio-code"

      # Productivity
      "alfred"
      "choosy"
      "obsidian"
      "chatgpt"
      "codex"

      # Security
      "nordvpn"
    ];
  };
}
