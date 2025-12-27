# darwin/mini/services/jellyfin.nix
# Jellyfin media server - Docker Compose with launchd auto-start
{ config, pkgs, lib, username, ... }:

let
  miniLib = import ../lib.nix { inherit config pkgs lib; };
  inherit (miniLib) mediaVolume userId groupId mkDockerComposeScripts mkLaunchdService;
  
  configDir = "${miniLib.configDir}/jellyfin";

  scripts = mkDockerComposeScripts {
    serviceName = "jellyfin";
    inherit configDir;
    # No extra env setup needed - Jellyfin doesn't use 1Password secrets
  };
in
{
  home.packages = scripts.scripts;

  # Create config directory
  home.file."${configDir}/.keep".text = "";

  home.file."${configDir}/docker-compose.yml".text = ''
    name: jellyfin

    services:
      jellyfin:
        container_name: jellyfin
        image: jellyfin/jellyfin:latest
        user: "${userId}:${groupId}"
        volumes:
          - ${mediaVolume}/jellyfin/config:/config
          - ${mediaVolume}/jellyfin/cache:/cache
          - ${mediaVolume}/jellyfin/jellyfin-library:/media/library:ro
          - ${mediaVolume}/jellyfin/jellyfin-books:/media/books:ro
        ports:
          - "8096:8096"
          - "8920:8920"
          - "7359:7359/udp"
        restart: unless-stopped
        environment:
          - TZ=Europe/Berlin
          - JELLYFIN_PublishedServerUrl=http://mini.local:8096
        healthcheck:
          test: curl -f http://localhost:8096/health || exit 1
          interval: 30s
          timeout: 10s
          retries: 3
  '';

  # launchd service for auto-start
  launchd.agents.jellyfin = mkLaunchdService {
    serviceName = "jellyfin";
    startScript = scripts.start;
    inherit configDir;
  };

  # Create log directory
  home.file."${config.home.homeDirectory}/.local/share/jellyfin/.keep".text = "";
}
