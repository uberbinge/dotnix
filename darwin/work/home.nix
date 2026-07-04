# darwin/work/home.nix
# Work Mac user-scoped packages. These used to be Homebrew formulae, but do not
# need to be installed machine-wide on a shared Mac.
{ pkgs, ... }:
{
  home.packages = with pkgs; [
    # Build & deployment
    just
    kubernetes-helm

    # Document processing
    pandoc
    gnupg

    # Development tools
    firebase-tools
    supabase-cli
    opencode
  ];
}
