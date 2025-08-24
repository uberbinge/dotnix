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
    cl4 = "aws-sso exec -p ai-coding.tools-ai-coding-maintainers -- claude --model eu.anthropic.claude-sonnet-4-20250514-v1:0";
    cl4d = "aws-sso exec -p ai-coding.tools-ai-coding-maintainers -- claude --dangerously-skip-permissions --model eu.anthropic.claude-sonnet-4-20250514-v1:0";
    cl = "aws-sso exec -p ai-coding.tools-ai-coding-maintainers -- claude";
    cld = "aws-sso exec -p ai-coding.tools-ai-coding-maintainers -- claude --dangerously-skip-permissions";
    unset-aws = "unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN AWS_PROFILE";
    # macOS-specific iCloud Obsidian path
    daily = "cd \"$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/\" && cl4 --continue";
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
