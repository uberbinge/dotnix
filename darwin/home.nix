{ pkgs, lib, username, ... }:
{
  home.homeDirectory = "/Users/${username}";
  home.sessionVariables = {
    PATH = "/opt/homebrew/bin:$PATH";
  };

  # macOS-specific shell configuration
  programs.zsh.initContent = ''
    # 1Password SSH Agent override (macOS sets SSH_AUTH_SOCK by default)
    if [[ "$(uname)" == "Darwin" ]]; then
      export SSH_AUTH_SOCK="$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
    fi
  '';

  # macOS-specific shell aliases
  programs.zsh.shellAliases = {
    # Work-specific AWS aliases (customize for your organization)
    cl4 = "claude --continue --model eu.anthropic.claude-sonnet-4-5-20250929-v1:0";
    cl4d = "claude --dangerously-skip-permissions --continue --model eu.anthropic.claude-sonnet-4-5-20250929-v1:0";
    unset-aws = "unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN AWS_PROFILE";
    # macOS-specific iCloud Obsidian path
    daily = "cd \"$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/\" && cl4";
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

  # Ghostty terminal configuration (installed via Homebrew)
  home.file.".config/ghostty/config".text = ''
    # Auto-switch between light and dark themes with macOS appearance
    theme = dark:catppuccin-mocha,light:catppuccin-latte

    # Font configuration
    font-family = FiraCode Nerd Font Mono
    font-size = 15

    # Save window state and layouts
    window-save-state = always

    # Native macOS titlebar
    macos-titlebar-style = native

    # Key bindings
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
