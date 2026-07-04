# darwin/homebrew/development.nix
# Development tools shared across machines
{ ... }:
{
  homebrew = {
    brews = [
      # Not currently packaged in pinned Nixpkgs.
      "awscurl"
    ];

    casks = [
      # Container runtime
      "orbstack"

      # Editors
      "visual-studio-code"
    ];
  };
}
