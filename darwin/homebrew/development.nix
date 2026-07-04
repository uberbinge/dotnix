# darwin/homebrew/development.nix
# Development tools shared across machines
{ ... }:
{
  homebrew = {
    brews = [
      # Not currently packaged or not reliably buildable in pinned Nixpkgs.
      "awscurl"
      "opa"
    ];

    casks = [
      # Container runtime
      "orbstack"

      # Editors
      "visual-studio-code"
    ];
  };
}
