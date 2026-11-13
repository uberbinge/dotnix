# darwin/mini/services/home-assistant.nix
# Home Assistant - Docker Compose with launchd auto-start
{ config, pkgs, lib, username, ... }:

let
  miniLib = import ../lib.nix { inherit config pkgs lib; };
  inherit (miniLib) mkDockerComposeScripts mkLaunchdService mkDockerComposeYaml;

  cfg = config.services.mediaServer;
  configDir = "${config.home.homeDirectory}/.config/home-assistant-config";
  serviceConfigDir = "${cfg.configDir}/home-assistant";
  homeAssistantImage = "homeassistant/home-assistant:2026.11.1@sha256:6785d1eca68747a524c156faae1b139ed415c07357386ae6fe17291986e59e82";

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
      ports = [ "127.0.0.1:8123:8123" ];
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
    if [ -z "''${DRY_RUN_CMD:-}" ]; then
    CONFIG_FILE="${configDir}/configuration.yaml"
    PACKAGE_DIR="${configDir}/packages"
    PACKAGE_FILE="$PACKAGE_DIR/caddy_proxy.yaml"

    $DRY_RUN_CMD mkdir -p "$PACKAGE_DIR"

    # Packages may only set `customize` under `homeassistant:`, so the URLs live in
    # configuration.yaml itself. Managed keys are rewritten; everything else is kept.
    if [ -f "$CONFIG_FILE" ]; then
      TMP_FILE="$(mktemp "$CONFIG_FILE.XXXXXX")"
      /usr/bin/awk '
        BEGIN { managed = "  packages: !include_dir_named packages\n  external_url: \"https://${cfg.domains.homeAssistant}\"" }
        /^homeassistant:/ { print; print managed; inblock = 1; found = 1; next }
        inblock && /^[^ #]/ { inblock = 0 }
        inblock && /^  (packages|external_url):/ { next }
        { print }
        END { if (!found) { print ""; print "homeassistant:"; print managed } }
      ' "$CONFIG_FILE" > "$TMP_FILE"
      if cmp -s "$TMP_FILE" "$CONFIG_FILE"; then
        rm -f "$TMP_FILE"
      else
        cp -p "$CONFIG_FILE" "$CONFIG_FILE.before-nix-urls"
        chmod 644 "$TMP_FILE"
        mv "$TMP_FILE" "$CONFIG_FILE"
      fi
    fi

    $DRY_RUN_CMD cat > "$PACKAGE_FILE" <<'YAML'
    http:
      use_x_forwarded_for: true
      trusted_proxies:
        - 192.168.147.1
    YAML
    else
      echo 'Would update Home Assistant proxy configuration'
    fi
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
