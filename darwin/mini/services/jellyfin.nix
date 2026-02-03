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
  logDir = "${config.home.homeDirectory}/.local/share/jellyfin/logs";

  # Management scripts
  jellyfinStart = pkgs.writeShellApplication {
    name = "jellyfin-start";
    text = ''
      echo "Starting Jellyfin..."
      launchctl start com.jellyfin.server || launchctl load ~/Library/LaunchAgents/com.jellyfin.server.plist
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
      launchctl stop com.jellyfin.server || true
      sleep 2
      launchctl start com.jellyfin.server
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
      LOG_FILE="${logDir}/jellyfin.log"
      if [ -f "$LOG_FILE" ]; then
        tail -f "$LOG_FILE"
      else
        echo "No log file found at $LOG_FILE"
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
  home.file."${logDir}/.keep".text = "";

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
      WorkingDirectory = dataDir;
      EnvironmentVariables = {
        HOME = config.home.homeDirectory;
        TZ = "Europe/Berlin";
      };
      StandardOutPath = "${logDir}/jellyfin.log";
      StandardErrorPath = "${logDir}/jellyfin.log";
    };
  };
}
