# darwin/mini/services/home-assistant.nix
# Home Assistant - Docker Compose with launchd auto-start
{ config, pkgs, lib, username, ... }:

let
  miniLib = import ../lib.nix { inherit config pkgs lib; };
  inherit (miniLib) mkDockerComposeScripts mkLaunchdService mkDockerComposeYaml;

  cfg = config.services.mediaServer;
  configDir = "${config.home.homeDirectory}/.config/home-assistant-config";
  serviceConfigDir = "${cfg.configDir}/home-assistant";
  homeAssistantImage = "homeassistant/home-assistant:2025.1.2@sha256:871f84a00db8d05856a70ee3761b138a8e91eb108d61f2fa176e7eeadb5eda03";

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
      image = homeAssistantImage;
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

    networks.default.ipam.config = [{
      subnet = "192.168.147.0/24";
      gateway = "192.168.147.1";
    }];
  };
in
{
  home.packages = scripts.scripts;

  # Create config directory
  home.file."${configDir}/.keep".text = "";

  # Create compose directory
  home.file."${serviceConfigDir}/.keep".text = "";

  home.activation.homeAssistantCaddyProxyConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    CONFIG_FILE="${configDir}/configuration.yaml"
    PACKAGE_DIR="${configDir}/packages"
    PACKAGE_FILE="$PACKAGE_DIR/caddy_proxy.yaml"

    $DRY_RUN_CMD mkdir -p "$PACKAGE_DIR"

    if [ -f "$CONFIG_FILE" ] && ! grep -q "packages: !include_dir_named packages" "$CONFIG_FILE"; then
      if ! grep -q "^homeassistant:" "$CONFIG_FILE"; then
        $DRY_RUN_CMD cp -p "$CONFIG_FILE" "$CONFIG_FILE.before-caddy-proxy"
        $DRY_RUN_CMD printf '\nhomeassistant:\n  packages: !include_dir_named packages\n' >> "$CONFIG_FILE"
      else
        echo "Home Assistant already has a homeassistant: block; ensure it contains: packages: !include_dir_named packages"
      fi
    fi

    $DRY_RUN_CMD cat > "$PACKAGE_FILE" <<'YAML'
    http:
      use_x_forwarded_for: true
      trusted_proxies:
        - 192.168.147.1

    homeassistant:
      external_url: "https://${cfg.domains.homeAssistant}"
      internal_url: "http://127.0.0.1:8123"
    YAML
  '';

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
