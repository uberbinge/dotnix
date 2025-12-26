# darwin/mini/default.nix
# Mac Mini media server home-manager configuration
{ config, pkgs, lib, ... }:

let
  # Volume paths for media storage
  mediaVolume = "/Volumes/4tb";
  configDir = "${config.home.homeDirectory}/.config/media-server";
in
{
  imports = [
    ./services/immich.nix
    ./services/jellyfin.nix
    ./services/paperless.nix
    ./scripts.nix
    ./borgmatic.nix
    ./caddy.nix
  ];

  # Pass volume paths to other modules
  home.sessionVariables = {
    MEDIA_VOLUME = mediaVolume;
    MEDIA_CONFIG_DIR = configDir;
  };

  # Create config directory structure
  home.file."${configDir}/.keep".text = "";
  home.file."${configDir}/immich/.keep".text = "";
  home.file."${configDir}/jellyfin/.keep".text = "";
  home.file."${configDir}/paperless/.keep".text = "";
  home.file."${configDir}/borgmatic/.keep".text = "";
  home.file."${configDir}/borgmatic/ssh/.keep".text = "";
  home.file."${configDir}/borgmatic/logs/.keep".text = "";
}
