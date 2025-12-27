# darwin/mini/lib.nix
# Shared library functions for Mac Mini media server services
{ config, pkgs, lib, ... }:

let
  # Common configuration values
  mediaVolume = "/Volumes/4tb";
  configDir = "${config.home.homeDirectory}/.config/media-server";
  
  # User/group IDs for Docker containers
  userId = "501";
  groupId = "20";

  # Common Docker Compose management functions
  mkDockerComposeScripts = { serviceName, configDir, extraEnvSetup ? "" }:
    let
      start = pkgs.writeShellScriptBin "${serviceName}-start" ''
        set -euo pipefail
        ${extraEnvSetup}
        echo "Starting ${serviceName}..."
        cd "${configDir}"
        ${pkgs.docker}/bin/docker compose up -d
        echo "${serviceName} started successfully"
      '';

      stop = pkgs.writeShellScriptBin "${serviceName}-stop" ''
        set -euo pipefail
        echo "Stopping ${serviceName}..."
        cd "${configDir}"
        ${pkgs.docker}/bin/docker compose down
        echo "${serviceName} stopped"
      '';

      logs = pkgs.writeShellScriptBin "${serviceName}-logs" ''
        cd "${configDir}"
        ${pkgs.docker}/bin/docker compose logs -f "''${1:-}"
      '';

      status = pkgs.writeShellScriptBin "${serviceName}-status" ''
        cd "${configDir}"
        ${pkgs.docker}/bin/docker compose ps
      '';

      restart = pkgs.writeShellScriptBin "${serviceName}-restart" ''
        ${stop}/bin/${serviceName}-stop
        ${start}/bin/${serviceName}-start
      '';

      update = pkgs.writeShellScriptBin "${serviceName}-update" ''
        set -euo pipefail
        echo "Pulling latest ${serviceName} images..."
        cd "${configDir}"
        ${pkgs.docker}/bin/docker compose pull
        echo "Restarting with new images..."
        ${restart}/bin/${serviceName}-restart
        echo "${serviceName} updated successfully"
      '';
    in
    {
      inherit start stop logs status restart update;
      scripts = [ start stop logs status restart update ];
    };

  # Common launchd service configuration
  mkLaunchdService = { serviceName, startScript, configDir }:
    {
      enable = true;
      config = {
        Label = "com.${serviceName}.docker-compose";
        ProgramArguments = [ "${startScript}/bin/${serviceName}-start" ];
        RunAtLoad = true;
        KeepAlive = false;
        WorkingDirectory = configDir;
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
  # Usage: SECRET=${fetch1PasswordSecret { item = "my-item"; }}
  fetch1PasswordSecret = { vault ? "Private", item, field ? "password" }:
    ''$(${pkgs._1password-cli}/bin/op read "op://${vault}/${item}/${field}" 2>/dev/null)'';

  # Validate 1Password secret was fetched
  # Generates shell code to check if a secret variable is non-empty
  # Usage: ${validate1PasswordSecret { secretVar = "MY_SECRET"; item = "my-item"; }}
  validate1PasswordSecret = { secretVar, item, field ? "password", vault ? "Private" }:
    ''
      if [ -z "$${secretVar}" ]; then
        echo "ERROR: Failed to load ${item} ${field} from 1Password" >&2
        echo "Ensure '${item}' item exists in ${vault} vault with '${field}' field" >&2
        exit 1
      fi
    '';
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
    validate1PasswordSecret;
}
