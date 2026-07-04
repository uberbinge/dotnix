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
        HOMEBREW_BUNDLE_BREW_SKIP = "mise aws-sso-cli awscli awscurl golangci-lint gofumpt opentofu conftest opa regal yq sqlite gemini-cli charmbracelet/tap/crush mas mole just helm scrcpy pandoc gnupg firebase-cli supabase anomalyco/tap/opencode";
      };
    };
    global = {
      brewfile = true;
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
