{ pkgs, lib, username, system, self, ... }:
{
  # Set the primary user for user-specific settings (Homebrew, launchd, etc.)
  # This is the main fix for the nix-darwin error.
  system.primaryUser = username;

  environment.systemPackages = with pkgs; [
    # Docker removed - provided by OrbStack via Homebrew
  ];

  fonts.packages = with pkgs; [
    nerd-fonts.fira-code
  ];

  imports = [
    ./homebrew/common.nix # Shared macOS apps (1Password, Ghostty, Tailscale)
    ./homebrew/development.nix # Brew-only formulae and shared dev apps
    ./homebrew/productivity.nix # Shared productivity GUI apps
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
    watchIdAuth = false; # Disabled - Swift build fails on nixpkgs
    reattach = true; # Enable Touch ID in tmux sessions
  };

  # All macOS defaults are now declarative in ./defaults.nix
  # nix-darwin automatically restarts Dock/Finder when their settings change
  # No imperative activation scripts needed

  programs.zsh.enable = true;
  # oh-my-zsh (via home-manager) already runs `compinit -i`, which safely
  # ignores insecure completion dirs. Without this, nix-darwin's system
  # /etc/zshrc runs a bare `compinit` first, which prompts on the shared,
  # group-writable Homebrew install (used by multiple users on this machine).
  programs.zsh.enableCompletion = false;
  environment.shells = [ pkgs.zsh ];
  users.users.${username} = {
    name = username;
    home = "/Users/${username}";
  };
}
