# darwin/homebrew/common.nix
# Essential apps for ALL Darwin machines
{ ... }:
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

    brews = [
      "mas"   # Mac App Store CLI
      "mole"  # Terminal file manager (tw93/tap)
    ];

    casks = [
      # Terminal & Fonts
      "ghostty@tip"
      "font-fira-code-nerd-font"

      # Security (required on all machines)
      "1password"
      "1password-cli"
      "tailscale-app"
    ];
  };
}
