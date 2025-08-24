# linux/home.nix
{ pkgs, lib, username, ... }:
{
  home = {
    homeDirectory = "/home/${username}";
    packages = with pkgs; [
      # Linux-specific packages can be added here if needed
    ];
  };
  # ... other Linux-specific configurations ...
}