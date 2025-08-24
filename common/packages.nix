{ pkgs, ... }:
{
  home.packages = with pkgs; [
    # Common packages for all systems
    gnumake
    git
    ripgrep
  ];
}