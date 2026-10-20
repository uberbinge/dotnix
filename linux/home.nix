# linux/home.nix
{ pkgs, lib, username, ... }:
{
  home = {
    homeDirectory = "/home/${username}";
    packages = with pkgs; [
      aws-sso-cli
      xclip
    ];
  };

  # Linux-specific shell configuration
  programs.zsh.initContent = ''
    # Linux-specific 1Password SSH Agent path (if using GUI version)
    # Uncomment and adjust if using 1Password on Linux
    # export SSH_AUTH_SOCK="$HOME/.1password/agent.sock"
  '';

  # Linux-specific shell aliases
  programs.zsh.shellAliases = {
    # Add Linux-specific aliases here if needed
  };
}
