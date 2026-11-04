# darwin/mini/lib.nix
# Shared library functions for Mac Mini media server services
{ config, pkgs, lib, ... }:

let
  # Get values from module options
  cfg = config.services.mediaServer;
  mediaVolume = cfg.mediaVolume;
  configDir = cfg.configDir;
  userId = cfg.userId;
  groupId = cfg.groupId;
  vault = cfg.onePassword.vault;

  # Common Docker Compose management functions using writeShellApplication for validation
  mkDockerComposeScripts =
    { serviceName
    , serviceConfigDir
    , preStart ? ""
    , # Hook before docker compose --env-file /dev/null up
      postStart ? ""
    , # Hook after docker compose --env-file /dev/null up
      preStop ? ""
    , # Hook before docker compose --env-file /dev/null down
      postStop ? ""
    , # Hook after docker compose --env-file /dev/null down
      extraEnvSetup ? ""
    }:
    let
      start = pkgs.writeShellApplication {
        name = "${serviceName}-start";
        runtimeInputs = [ pkgs.docker pkgs._1password-cli ];
        text = ''
          # Login ordering is not guaranteed: wait briefly for the container engine.
          ready=false
          for ((attempt = 1; attempt <= 15; attempt++)); do
            if ${pkgs.coreutils}/bin/timeout --kill-after=2 3 docker info >/dev/null 2>&1; then
              ready=true
              break
            fi
            sleep 2
          done
          if [ "$ready" != true ]; then
            echo "Docker is unavailable; retry ${serviceName}-start after starting Docker." >&2
            exit 1
          fi
          COMPOSE_VERSION=$(docker compose version --short)
          if [[ ! "$COMPOSE_VERSION" =~ ^v?([0-9]+)\.([0-9]+) ]] ||
             (( BASH_REMATCH[1] < 2 || (BASH_REMATCH[1] == 2 && BASH_REMATCH[2] < 30) )); then
            echo "Docker Compose >=2.30 is required for literal secret env files; update Docker first." >&2
            exit 1
          fi
          ${extraEnvSetup}
          ${preStart}
          echo "Starting ${serviceName}..."
          cd "${serviceConfigDir}"
          docker compose --env-file /dev/null up -d
          echo "${serviceName} started successfully"
          ${postStart}
        '';
      };

      stop = pkgs.writeShellApplication {
        name = "${serviceName}-stop";
        runtimeInputs = [ pkgs.docker ];
        text = ''
          ${preStop}
          echo "Stopping ${serviceName}..."
          cd "${serviceConfigDir}"
          docker compose --env-file /dev/null down
          echo "${serviceName} stopped"
          ${postStop}
        '';
      };

      logs = pkgs.writeShellApplication {
        name = "${serviceName}-logs";
        runtimeInputs = [ pkgs.docker ];
        text = ''
          cd "${serviceConfigDir}"
          docker compose --env-file /dev/null logs -f "$@"
        '';
      };

      status = pkgs.writeShellApplication {
        name = "${serviceName}-status";
        runtimeInputs = [ pkgs.docker ];
        text = ''
          cd "${serviceConfigDir}"
          docker compose --env-file /dev/null ps
        '';
      };

      restart = pkgs.writeShellApplication {
        name = "${serviceName}-restart";
        runtimeInputs = [ pkgs.docker ];
        text = ''
          ${stop}/bin/${serviceName}-stop
          ${start}/bin/${serviceName}-start
        '';
      };

      update = pkgs.writeShellApplication {
        name = "${serviceName}-update";
        runtimeInputs = [ pkgs.docker ];
        text = ''
          echo "Pulling latest ${serviceName} images..."
          cd "${serviceConfigDir}"
          docker compose --env-file /dev/null pull
          echo "Restarting with new images..."
          ${restart}/bin/${serviceName}-restart
          echo "${serviceName} updated successfully"
        '';
      };
    in
    {
      inherit start stop logs status restart update;
      scripts = [ start stop logs status restart update ];
    };

  # Common launchd service configuration
  mkLaunchdService = { serviceName, startScript, serviceConfigDir }:
    {
      enable = true;
      config = {
        Label = "com.${serviceName}.docker-compose";
        ProgramArguments = [ "${startScript}/bin/${serviceName}-start" ];
        RunAtLoad = true;
        KeepAlive = false;
        WorkingDirectory = serviceConfigDir;
        EnvironmentVariables = {
          HOME = config.home.homeDirectory;
          PATH = "${pkgs.docker}/bin:${pkgs._1password-cli}/bin:/usr/bin:/bin";
        };
        StandardOutPath = "${config.home.homeDirectory}/.local/share/${serviceName}/launchd.log";
        StandardErrorPath = "${config.home.homeDirectory}/.local/share/${serviceName}/launchd.log";
      };
    };

  # Common 1Password secret fetching
  # Returns a shell expression string that will be evaluated at runtime to fetch the secret
  fetch1PasswordSecret = { vault ? cfg.onePassword.vault, item, field ? "password" }:
    ''$(if secret_value=$(${pkgs.coreutils}/bin/timeout --kill-after=2 20 op read "op://${vault}/${item}/${field}" 2>/dev/null); then       printf '%s' "$secret_value"; else       echo "ERROR: 1Password read failed or timed out; unlock/authorize it and retry manually." >&2; exit 1;     fi)'';

  # Validate 1Password secret was fetched
  # Generates shell code to check if a secret variable is non-empty
  validate1PasswordSecret = { secretVar, item, field ? "password", vault ? cfg.onePassword.vault }:
    ''
      if [ -z "''$${secretVar}" ]; then
        echo "ERROR: Failed to load ${item} ${field} from 1Password" >&2
        echo "Ensure '${item}' item exists in ${vault} vault with '${field}' field" >&2
        exit 1
      fi
    '';

  # Generate Docker Compose YAML from Nix attribute set
  mkDockerComposeYaml = name: composeConfig:
    let
      yamlFormat = pkgs.formats.yaml { };
    in
    yamlFormat.generate "${name}-docker-compose.yml" composeConfig;

in
{
  inherit
    mediaVolume
    configDir
    userId
    groupId
    mkDockerComposeScripts
    mkLaunchdService
    fetch1PasswordSecret
    validate1PasswordSecret
    mkDockerComposeYaml;
}
