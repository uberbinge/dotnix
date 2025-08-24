{ pkgs, lib, username, ... }:
{
  home.homeDirectory = "/Users/${username}";
  home.sessionVariables = {
    PATH = "/opt/homebrew/bin:$PATH";
  };

  imports = [
    ./alfred.nix
  ];

  home.packages = with pkgs; [
    # Darwin-specific packages can be added here if needed
    
    # Simple homebrew update script
    (writeShellScriptBin "update-homebrew-apps" ''
      #!/bin/bash
      echo "🔄 Updating all Homebrew casks and formulae..."
      brew update
      brew upgrade
      echo "✅ All apps updated!"
      echo ""
      echo "💡 Browser extensions should be preserved automatically"
    '')
  ];

  home.file.".local/share/mise/config.toml".text = ''
idiomatic_version_file_enable_tools = []
'';

  # Ghostty terminal configuration
  home.file.".config/ghostty/config".text = ''
font-family = FiraCode Nerd Font Mono
font-size = 15

# Save window state and layouts
window-save-state = "always"
keybind = shift+enter=text:\n
'';

  home.activation = {
    resetLaunchPad = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin (lib.hm.dag.entryBefore ["installPackages"] ''
      /usr/bin/defaults write com.apple.dock ResetLaunchPad -bool true
      echo "Restarting Dock to reset LaunchPad..."
      /usr/bin/killall Dock
    '');
  };
}
