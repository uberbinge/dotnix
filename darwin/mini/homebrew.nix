# darwin/mini/homebrew.nix
# Mac Mini ONLY - apps not needed on other machines
{ ... }:
{
  homebrew = {
    casks = [
      "jellyfin"  # Native media server with Apple Silicon optimization
    ];
  };
}
