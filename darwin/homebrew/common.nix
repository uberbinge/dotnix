# darwin/homebrew/common.nix
# Essential apps for ALL Darwin machines
{ ... }:
{
  homebrew = {
    enable = true;
    onActivation = {
      cleanup = "none";
      upgrade = false;
    };
    global = {
      brewfile = true;
    };

    taps = [
      "tw93/tap"
    ];

    brews = [
      # Nixpkgs currently marks this package as broken.
      "mole"
    ];

    casks = [
      # Terminal
      "ghostty@tip"

      # Security (required on all machines)
      "1password"
      "tailscale-app"
    ];
  };
}
