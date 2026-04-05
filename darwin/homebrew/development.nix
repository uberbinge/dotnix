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
      "awscli"
      "awscurl"

      # Go tools
      "golangci-lint"

      # Infrastructure & policy
      "conftest"
      "opa"
      "regal"

      # Database
      "sqlite"

      # AI tools
      "gemini-cli"
      "charmbracelet/tap/crush"
      "charmbracelet/tap/glow"
    ];

    casks = [
      # Container runtime
      "orbstack"

      # Editors
      "visual-studio-code"

      # AI
      "codex"
      "kitlangton-hex"
    ];
  };
}
