{ pkgs, lib, username, system, self, ... }:
let
in
{
  # Set the primary user for user-specific settings (Homebrew, launchd, etc.)
  # This is the main fix for the nix-darwin error.
  system.primaryUser = username;

  environment.systemPackages = with pkgs; [
    # Docker removed - provided by OrbStack via Homebrew
  ];

  imports = [
    ./homebrew-common.nix  # Shared Homebrew apps for all machines
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
  security.pam.services.sudo_local.touchIdAuth = true;

  # Post-activation script that runs as root after the system has been built.
  # User-specific commands are run via `sudo -u`.
  system.activationScripts.postActivation = {
    text = ''
      # Run user-specific commands as the primary user.
      sudo -u ${username} -- sh -c '
        # Apply system settings changes immediately without requiring a logout
        /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u

        # Configure and restart Dock properly to ensure settings are applied
        echo "Configuring Dock settings..."
        defaults write com.apple.dock autohide -bool TRUE
        defaults write com.apple.dock autohide-delay -float 0.0
        defaults write com.apple.dock autohide-time-modifier -float 0.0
        defaults write com.apple.dock showhidden -bool TRUE
        defaults write com.apple.dock showDesktopGestureEnabled -bool TRUE
        defaults write com.apple.dock showLaunchpadGestureEnabled -bool TRUE

        # Force restart the Dock process to apply all changes
        echo "Restarting Dock to apply changes..."
        killall Dock || echo "Dock was not running"
        sleep 1
        open -a Dock

        # Clean up any failed or unnecessary Homebrew taps
        if command -v brew >/dev/null 2>&1; then
          echo "Cleaning up Homebrew taps..."
          brew untap homebrew/cask-fonts homebrew/cask-versions homebrew/services 2>/dev/null || true
        fi
      '
    '';
  };

  programs.zsh.enable = true;
  environment.shells = [ pkgs.zsh ];
  users.users.${username} = {
    name = username;
    home = "/Users/${username}";
  };
}
