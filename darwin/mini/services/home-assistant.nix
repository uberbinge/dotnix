# darwin/mini/services/home-assistant.nix
# Home Assistant - Docker Compose with launchd auto-start
{ config, pkgs, lib, username, ... }:

let
  configDir = "${config.home.homeDirectory}/.config/home-assistant-config";
  composeDir = "${config.home.homeDirectory}/.config/media-server/home-assistant";

  haStart = pkgs.writeShellScriptBin "ha-start" ''
    set -euo pipefail
    echo "Starting Home Assistant..."
    cd "${composeDir}"
    ${pkgs.docker-compose}/bin/docker-compose up -d
    echo "Home Assistant started successfully"
    echo "Access at: http://localhost:8123"
  '';

  haStop = pkgs.writeShellScriptBin "ha-stop" ''
    set -euo pipefail
    echo "Stopping Home Assistant..."
    cd "${composeDir}"
    ${pkgs.docker-compose}/bin/docker-compose down
    echo "Home Assistant stopped"
  '';

  haLogs = pkgs.writeShellScriptBin "ha-logs" ''
    cd "${composeDir}"
    ${pkgs.docker-compose}/bin/docker-compose logs -f
  '';

  haStatus = pkgs.writeShellScriptBin "ha-status" ''
    cd "${composeDir}"
    ${pkgs.docker-compose}/bin/docker-compose ps
  '';

  haRestart = pkgs.writeShellScriptBin "ha-restart" ''
    ${haStop}/bin/ha-stop
    ${haStart}/bin/ha-start
  '';

  haUpdate = pkgs.writeShellScriptBin "ha-update" ''
    set -euo pipefail
    echo "Pulling latest Home Assistant image..."
    cd "${composeDir}"
    ${pkgs.docker-compose}/bin/docker-compose pull
    echo "Restarting with new image..."
    ${haRestart}/bin/ha-restart
    echo "Home Assistant updated successfully"
  '';
in
{
  home.packages = [
    haStart
    haStop
    haLogs
    haStatus
    haRestart
    haUpdate
  ];

  # Create config directory
  home.file."${configDir}/.keep".text = "";

  # Create compose directory
  home.file."${composeDir}/.keep".text = "";

  # Docker Compose configuration
  home.file."${composeDir}/docker-compose.yml".text = ''
    name: home-assistant

    services:
      home-assistant:
        container_name: home-assistant
        image: homeassistant/home-assistant:latest
        volumes:
          - ${configDir}:/config
          - /etc/localtime:/etc/localtime:ro
        ports:
          - "8123:8123"
        environment:
          - TZ=Europe/Berlin
        restart: unless-stopped
        healthcheck:
          test: ["CMD", "curl", "-f", "http://localhost:8123"]
          interval: 30s
          timeout: 10s
          retries: 3
  '';

  # launchd service for auto-start
  launchd.agents.home-assistant = {
    enable = true;
    config = {
      Label = "com.home-assistant.docker-compose";
      ProgramArguments = [
        "${haStart}/bin/ha-start"
      ];
      RunAtLoad = true;
      KeepAlive = false;
      WorkingDirectory = composeDir;
      EnvironmentVariables = {
        HOME = config.home.homeDirectory;
        PATH = "${pkgs.docker}/bin:/usr/bin:/bin";
      };
      StandardOutPath = "${config.home.homeDirectory}/.local/share/home-assistant/launchd.log";
      StandardErrorPath = "${config.home.homeDirectory}/.local/share/home-assistant/launchd.log";
    };
  };

  # Create log directory
  home.file."${config.home.homeDirectory}/.local/share/home-assistant/.keep".text = "";
}
