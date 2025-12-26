# darwin/homebrew-common.nix
# Shared Homebrew configuration for all Darwin machines
{ pkgs, lib, ... }:
{
  homebrew = {
    enable = true;
    onActivation = {
      cleanup = "none";
      upgrade = true;
    };
    global = {
      brewfile = true;
      lockfiles = true;
    };

    taps = [
      "tw93/tap"
    ];

    # Common brews for all machines
    brews = [
      "mas"  # Mac App Store CLI
      "mole" # Terminal file manager (tw93/tap)
    ];

    # Common casks for all machines
    casks = [
      # Terminal & Fonts
      "ghostty@tip"
      "font-fira-code-nerd-font"

      # Security
      "1password"
      "1password-cli"
      "tailscale-app"
    ];

    masApps = {
      # Common Mac App Store apps (if any)
    };
  };
}
