# darwin/mini/services/jellyfin.nix
# Jellyfin media server - Docker Compose with launchd auto-start
{ config, pkgs, lib, username, ... }:

let
  mediaVolume = "/Volumes/4tb";
  configDir = "${config.home.homeDirectory}/.config/media-server/jellyfin";
  composeFile = "${configDir}/docker-compose.yml";

  jellyfinStart = pkgs.writeShellScriptBin "jellyfin-start" ''
    set -euo pipefail
    echo "Starting Jellyfin..."
    cd "${configDir}"
    ${pkgs.docker-compose}/bin/docker-compose up -d
    echo "Jellyfin started successfully"
  '';

  jellyfinStop = pkgs.writeShellScriptBin "jellyfin-stop" ''
    set -euo pipefail
    echo "Stopping Jellyfin..."
    cd "${configDir}"
    ${pkgs.docker-compose}/bin/docker-compose down
    echo "Jellyfin stopped"
  '';

  jellyfinLogs = pkgs.writeShellScriptBin "jellyfin-logs" ''
    cd "${configDir}"
    ${pkgs.docker-compose}/bin/docker-compose logs -f
  '';

  jellyfinStatus = pkgs.writeShellScriptBin "jellyfin-status" ''
    cd "${configDir}"
    ${pkgs.docker-compose}/bin/docker-compose ps
  '';

  jellyfinRestart = pkgs.writeShellScriptBin "jellyfin-restart" ''
    ${jellyfinStop}/bin/jellyfin-stop
    ${jellyfinStart}/bin/jellyfin-start
  '';

  jellyfinUpdate = pkgs.writeShellScriptBin "jellyfin-update" ''
    set -euo pipefail
    echo "Pulling latest Jellyfin image..."
    cd "${configDir}"
    ${pkgs.docker-compose}/bin/docker-compose pull
    echo "Restarting with new image..."
    ${jellyfinRestart}/bin/jellyfin-restart
    echo "Jellyfin updated successfully"
  '';
in
{
  home.packages = [
    jellyfinStart
    jellyfinStop
    jellyfinLogs
    jellyfinStatus
    jellyfinRestart
    jellyfinUpdate
  ];

  # Create config directory
  home.file."${configDir}/.keep".text = "";

  # Docker Compose configuration
  home.file."${configDir}/docker-compose.yml".text = ''
    name: jellyfin

    services:
      jellyfin:
        container_name: jellyfin
        image: jellyfin/jellyfin:latest
        user: "501:20"
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
  launchd.agents.jellyfin = {
    enable = true;
    config = {
      Label = "com.jellyfin.docker-compose";
      ProgramArguments = [
        "${jellyfinStart}/bin/jellyfin-start"
      ];
      RunAtLoad = true;
      KeepAlive = false;
      WorkingDirectory = configDir;
      EnvironmentVariables = {
        HOME = config.home.homeDirectory;
        PATH = "${pkgs.docker}/bin:/usr/bin:/bin";
      };
      StandardOutPath = "${config.home.homeDirectory}/.local/share/jellyfin/launchd.log";
      StandardErrorPath = "${config.home.homeDirectory}/.local/share/jellyfin/launchd.log";
    };
  };

  # Create log directory
  home.file."${config.home.homeDirectory}/.local/share/jellyfin/.keep".text = "";
}
