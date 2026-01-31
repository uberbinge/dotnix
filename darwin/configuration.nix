{ pkgs, lib, username, system, self, ... }:
{
  # Set the primary user for user-specific settings (Homebrew, launchd, etc.)
  # This is the main fix for the nix-darwin error.
  system.primaryUser = username;

  environment.systemPackages = with pkgs; [
    # Docker removed - provided by OrbStack via Homebrew
  ];

  imports = [
    ./homebrew/common.nix       # Essential apps (1password, ghostty, tailscale)
    ./homebrew/development.nix  # Dev tools (mise, aws, orbstack, editors)
    ./homebrew/productivity.nix # Productivity (alfred, obsidian, nordvpn)
    ./defaults.nix
  ];

  nixpkgs.config.allowUnfree = true;
  nix.settings.experimental-features = "nix-command flakes";
  system.configurationRevision = self.rev or self.dirtyRev or null;
  system.stateVersion = 5;
  nixpkgs.hostPlatform = system;
  nix.gc = {
    automatic = lib.mkDefault true;
    options = lib.mkDefault "--delete-older-than 7d";
  };
  nix.settings.auto-optimise-store = false;
  security.pam.services.sudo_local = {
    touchIdAuth = true;
    watchIdAuth = false;  # Disabled - Swift build fails on nixpkgs
    reattach = true;      # Enable Touch ID in tmux sessions
  };

  # All macOS defaults are now declarative in ./defaults.nix
  # nix-darwin automatically restarts Dock/Finder when their settings change
  # No imperative activation scripts needed

  programs.zsh.enable = true;
  environment.shells = [ pkgs.zsh ];
  users.users.${username} = {
    name = username;
    home = "/Users/${username}";
  };
}
