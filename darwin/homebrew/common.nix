# darwin/homebrew/common.nix
# Essential apps for ALL Darwin machines
{ ... }:
{
  homebrew = {
    enable = true;
    onActivation = {
      cleanup = "none";
      upgrade = false;
      extraEnv = {
        # Work around Homebrew Bundle 6.0.1 crashing while sorting installed
        # formulae from untrusted third-party taps that are not in this Brewfile.
        HOMEBREW_BUNDLE_BREW_SKIP = "mise aws-sso-cli awscli golangci-lint gofumpt opentofu conftest regal yq sqlite gemini-cli charmbracelet/tap/crush mas just helm scrcpy pandoc gnupg firebase-cli supabase anomalyco/tap/opencode";
      };
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
