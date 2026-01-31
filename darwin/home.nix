{ pkgs, lib, username, ... }:
{
  home.homeDirectory = "/Users/${username}";

  home.sessionVariables = {
    PATH = "/opt/homebrew/bin:$PATH";
  };

  # macOS-specific shell configuration
  programs.zsh.initContent = lib.mkAfter ''
    # 1Password SSH Agent override (macOS sets SSH_AUTH_SOCK by default)
    export SSH_AUTH_SOCK="$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
  '';

  # macOS-specific shell aliases
  programs.zsh.shellAliases = {
    cl4c = "claude --continue";
    cl4dc = "claude --dangerously-skip-permissions --continue";
    unset-aws = "unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN AWS_PROFILE";
    # macOS-specific iCloud Obsidian path
    daily = "cd \"$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/den/daily\" && cl4c";
  };

  imports = [
    ./alfred.nix
  ];

  home.packages = with pkgs; [
    # Simple homebrew update script using writeShellApplication
    (writeShellApplication {
      name = "update-homebrew-apps";
      runtimeInputs = [ ];  # brew is in /opt/homebrew/bin via PATH
      text = ''
        echo "Updating all Homebrew casks and formulae..."
        /opt/homebrew/bin/brew update
        /opt/homebrew/bin/brew upgrade
        echo "All apps updated!"
        echo ""
        echo "Browser extensions should be preserved automatically"
      '';
    })

    # Jujutsu TUI
    jjui
  ];

  home.file.".local/share/mise/config.toml".text = ''
    idiomatic_version_file_enable_tools = []
  '';

  # Ghostty terminal configuration (installed via Homebrew)
  home.file.".config/ghostty/config".text = ''
    # Dark theme only
    theme = Catppuccin Mocha

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
    # Use 'run' helper to respect --dry-run mode
    resetLaunchPad = lib.hm.dag.entryBefore [ "installPackages" ] ''
      run /usr/bin/defaults write com.apple.dock ResetLaunchPad -bool true
      verboseEcho "Restarting Dock to reset LaunchPad..."
      run /usr/bin/killall Dock || true
    '';

    # Install Ghostty terminfo for SSH sessions
    installGhosttyTerminfo = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      GHOSTTY_TERMINFO="/Applications/Ghostty.app/Contents/Resources/terminfo"
      if [ -d "$GHOSTTY_TERMINFO" ]; then
        verboseEcho "Installing Ghostty terminfo..."
        mkdir -p "$HOME/.terminfo"
        cp -r "$GHOSTTY_TERMINFO"/* "$HOME/.terminfo/" 2>/dev/null || true
      fi
    '';
  };
}
