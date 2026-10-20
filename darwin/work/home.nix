# darwin/work/home.nix
# Firebase's Brew formula adds a globally visible Node dependency. Keep this
# one development CLI inside the Nix user profile; other dev CLIs use Brew.
{ pkgs, ... }:
{
  home.packages = [ pkgs.firebase-tools ];
}
