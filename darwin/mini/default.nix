# darwin/mini/default.nix
# Mac Mini media server home-manager configuration
{ config, pkgs, lib, ... }:

let
  cfg = config.services.mediaServer;
  alfredIcon = "${config.home.homeDirectory}/.config/alfred/brave.png";
in
{
  imports = [
    ./options.nix
    ./services/home-assistant.nix
    ./services/health-server.nix
    ./services/immich.nix
    ./services/jellyfin.nix
    ./services/paperless.nix
    ./services/tt-coach.nix
    ./scripts.nix
    ./borgmatic.nix
    ./caddy.nix
    ./local-backup.nix
  ];

  # Pass volume paths to other modules via session variables
  home.sessionVariables = {
    MEDIA_VOLUME = cfg.mediaVolume;
    MEDIA_CONFIG_DIR = cfg.configDir;
  };

  programs.alfredWebsiteHelper.extraPersonalSites = [
    {
      title = "paperless";
      arg = "https://${cfg.domains.paperless}";
      icon = alfredIcon;
    }
    {
      title = "immich";
      arg = "https://${cfg.domains.immich}";
      icon = alfredIcon;
    }
    {
      title = "jellyfin";
      arg = "https://${cfg.domains.jellyfin}";
      icon = alfredIcon;
    }
  ];

  # Create config directory structure
  home.file = {
    "${cfg.configDir}/.keep".text = "";
    "${cfg.configDir}/immich/.keep".text = "";
    "${cfg.configDir}/jellyfin/.keep".text = "";
    "${cfg.configDir}/paperless/.keep".text = "";
    "${cfg.configDir}/borgmatic/.keep".text = "";
    "${cfg.configDir}/borgmatic/ssh/.keep".text = "";
    "${cfg.configDir}/borgmatic/logs/.keep".text = "";
  };
}
