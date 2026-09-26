# darwin/mini/services/jellyfin.nix
# Jellyfin media server - Native macOS app with launchd auto-start
{ config, pkgs, lib, username, ... }:

let
  miniLib = import ../lib.nix { inherit config pkgs lib; };
  inherit (miniLib) mediaVolume;

  # Paths
  jellyfinApp = "/Applications/Jellyfin.app";
  jellyfinBin = "${jellyfinApp}/Contents/MacOS/jellyfin";
  jellyfinWeb = "${jellyfinApp}/Contents/Resources/jellyfin-web";
  jellyfinFfmpeg = "${jellyfinApp}/Contents/MacOS/ffmpeg";

  dataDir = "${mediaVolume}/jellyfin/config";
  cacheDir = "${mediaVolume}/jellyfin/cache";
  launchdLogDir = "${config.home.homeDirectory}/.local/state/jellyfin";

  # Management scripts
  jellyfinStart = pkgs.writeShellApplication {
    name = "jellyfin-start";
    text = ''
      echo "Starting Jellyfin..."
      launchctl kickstart -k "gui/$(id -u)/com.jellyfin.server" || launchctl start com.jellyfin.server
      echo "Jellyfin started. Access at http://localhost:8096"
    '';
  };

  jellyfinStop = pkgs.writeShellApplication {
    name = "jellyfin-stop";
    text = ''
      echo "Stopping Jellyfin..."
      launchctl stop com.jellyfin.server || true
      pkill -f "Jellyfin.app" || true
      echo "Jellyfin stopped."
    '';
  };

  jellyfinRestart = pkgs.writeShellApplication {
    name = "jellyfin-restart";
    text = ''
      echo "Restarting Jellyfin..."
      launchctl kickstart -k "gui/$(id -u)/com.jellyfin.server" || {
        launchctl stop com.jellyfin.server || true
        sleep 2
        launchctl start com.jellyfin.server
      }
      echo "Jellyfin restarted."
    '';
  };

  jellyfinStatus = pkgs.writeShellApplication {
    name = "jellyfin-status";
    runtimeInputs = [ pkgs.curl ];
    text = ''
      if pgrep -f "Jellyfin.app" > /dev/null; then
        echo "Jellyfin is running"
        if curl -sf http://localhost:8096/health > /dev/null 2>&1; then
          echo "Health check: OK"
        else
          echo "Health check: FAILED (service starting or unhealthy)"
        fi
      else
        echo "Jellyfin is not running"
      fi
    '';
  };

  jellyfinLogs = pkgs.writeShellApplication {
    name = "jellyfin-logs";
    text = ''
      LOG_FILE="$(find "${dataDir}/log" -name 'log_*.log' -type f -print 2>/dev/null | sort | tail -n 1 || true)"
      if [ -f "$LOG_FILE" ]; then
        tail -f "$LOG_FILE"
      else
        echo "No Jellyfin app log found under ${dataDir}/log"
        echo "LaunchAgent log is ${launchdLogDir}/jellyfin-launchd.log"
        echo "Check launchd logs: log show --predicate 'subsystem == \"com.jellyfin.server\"' --last 1h"
      fi
    '';
  };

  jellyfinUpdate = pkgs.writeShellApplication {
    name = "jellyfin-update";
    text = ''
      echo "Updating Jellyfin..."
      ${jellyfinStop}/bin/jellyfin-stop
      brew upgrade --cask jellyfin || brew reinstall --cask jellyfin
      ${jellyfinStart}/bin/jellyfin-start
      echo "Jellyfin updated."
    '';
  };

in
{
  home.packages = [
    jellyfinStart
    jellyfinStop
    jellyfinRestart
    jellyfinStatus
    jellyfinLogs
    jellyfinUpdate
  ];

  # Create required directories
  home.file."${launchdLogDir}/.keep".text = "";

  # launchd service for auto-start
  launchd.agents.jellyfin = {
    enable = true;
    config = {
      Label = "com.jellyfin.server";
      ProgramArguments = [
        jellyfinBin
        "--datadir" dataDir
        "--cachedir" cacheDir
        "--webdir" jellyfinWeb
        "--ffmpeg" jellyfinFfmpeg
      ];
      RunAtLoad = true;
      KeepAlive = true;
      # Keep launchd startup away from the external volume. Jellyfin still uses
      # the explicit data/cache paths above for all service data.
      WorkingDirectory = config.home.homeDirectory;
      EnvironmentVariables = {
        HOME = config.home.homeDirectory;
        TZ = "Europe/Berlin";
      };
      StandardOutPath = "${launchdLogDir}/jellyfin-launchd.log";
      StandardErrorPath = "${launchdLogDir}/jellyfin-launchd.log";
    };
  };
}
