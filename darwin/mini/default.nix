# darwin/mini/default.nix
# Mac Mini media server home-manager configuration
{ config, pkgs, lib, ... }:

let
  cfg = config.services.mediaServer;
in
{
  imports = [
    ./options.nix
    ./services/home-assistant.nix
    ./services/immich.nix
    ./services/jellyfin.nix
    ./services/paperless.nix
    ./scripts.nix
    ./borgmatic.nix
    ./caddy.nix
  ];

  # Pass volume paths to other modules via session variables
  home.sessionVariables = {
    MEDIA_VOLUME = cfg.mediaVolume;
    MEDIA_CONFIG_DIR = cfg.configDir;
  };

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
