# darwin/homebrew/development.nix
# Development tools shared across machines
{ ... }:
{
  homebrew = {
    brews = [
      # Brew-only or currently unreliable in nixpkgs on Darwin.
      "aws-sso-cli"
      "awscurl"
      "opa"

      # Standalone CLIs; Home Manager retains configured shell/VCS programs.
      "make"
      "coreutils"
      "gnu-sed"
      "mise"
      "lazygit"
      "git-delta"
      "fd"
      "yt-dlp"
      "jsonnet"
      "git-lfs"
      "grpcurl"
      "opentofu"
      "yq"
      "awscli"
      "golangci-lint"
      "conftest"
      "regal"
      "glow"

      # Terminal multiplexer for coding agents.
      "herdr"
    ];

    casks = [
      "1password-cli"

      # Container runtime
      "orbstack"

      # Editors
      "visual-studio-code"
    ];
  };
}
