# darwin/mini/homebrew.nix
# Mac Mini ONLY - apps not needed on other machines
# Currently empty - all mini apps are in shared configs:
#   - homebrew/common.nix (essentials)
#   - homebrew/development.nix (dev tools)
#   - homebrew/productivity.nix (productivity apps)
{ ... }:
{
  # Add mini-specific homebrew packages here if needed
  # homebrew = {
  #   brews = [ ];
  #   casks = [ ];
  # };
}
