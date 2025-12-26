# darwin/homebrew/productivity.nix
# Productivity apps shared across machines
{ ... }:
{
  homebrew = {
    casks = [
      # Launchers & utilities
      "alfred"
      "choosy"

      # Knowledge management
      "obsidian"

      # AI assistants
      "chatgpt"

      # Security
      "nordvpn"
    ];
  };
}
