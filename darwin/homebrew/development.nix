# darwin/homebrew/development.nix
# Development tools shared across machines
{ ... }:
{
  homebrew = {
    taps = [
      "charmbracelet/tap"
    ];

    brews = [
      # Runtime & tooling
      "mise"

      # AWS
      "aws-sso-cli"
      "awscli"

      # AI tools
      "gemini-cli"
      "charmbracelet/tap/crush"
    ];

    casks = [
      # Container runtime
      "orbstack"

      # Editors
      "cursor"
      "visual-studio-code"

      # AI
      "codex"
    ];
  };
}
