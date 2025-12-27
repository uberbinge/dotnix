# darwin/mini/services/home-assistant.nix
# Home Assistant - Docker Compose with launchd auto-start
{ config, pkgs, lib, username, ... }:

let
  miniLib = import ../lib.nix { inherit config pkgs lib; };
  inherit (miniLib) mkDockerComposeScripts mkLaunchdService mkDockerComposeYaml;

  cfg = config.services.mediaServer;
  configDir = "${config.home.homeDirectory}/.config/home-assistant-config";
  serviceConfigDir = "${cfg.configDir}/home-assistant";

  scripts = mkDockerComposeScripts {
    serviceName = "ha";
    inherit serviceConfigDir;
    postStart = ''
      echo "Access at: http://localhost:8123"
    '';
  };

  # Docker Compose configuration as structured Nix
  composeConfig = {
    name = "home-assistant";
    services.home-assistant = {
      container_name = "home-assistant";
      image = "homeassistant/home-assistant:latest";
      volumes = [
        "${configDir}:/config"
        "/etc/localtime:/etc/localtime:ro"
      ];
      ports = [ "8123:8123" ];
      environment.TZ = "Europe/Berlin";
      restart = "unless-stopped";
      healthcheck = {
        test = [ "CMD" "curl" "-f" "http://localhost:8123" ];
        interval = "30s";
        timeout = "10s";
        retries = 3;
      };
    };
  };
in
{
  home.packages = scripts.scripts;

  # Create config directory
  home.file."${configDir}/.keep".text = "";

  # Create compose directory
  home.file."${serviceConfigDir}/.keep".text = "";

  # Docker Compose configuration - generated from structured Nix
  home.file."${serviceConfigDir}/docker-compose.yml".source =
    mkDockerComposeYaml "home-assistant" composeConfig;

  # launchd service for auto-start
  launchd.agents.home-assistant = mkLaunchdService {
    serviceName = "ha";
    startScript = scripts.start;
    inherit serviceConfigDir;
  };

  # Create log directory
  home.file."${config.home.homeDirectory}/.local/share/ha/.keep".text = "";
}
