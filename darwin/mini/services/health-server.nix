# darwin/mini/services/health-server.nix
# Health Export Server - Go binary syncing Apple HealthKit data
# Usage: cd ~/dev/health-export/health-server && just deploy
{ config, pkgs, lib, ... }:

let
  serverDir = "${config.home.homeDirectory}/dev/health-export/health-server";
  dataDir = "${serverDir}/data";
  binary = "${serverDir}/health";
  logFile = "${dataDir}/server.log";
in
{
  # launchd service for auto-start
  launchd.agents.health-server = {
    enable = true;
    config = {
      Label = "dev.waqas.health-server";
      ProgramArguments = [ binary "server" ];
      RunAtLoad = true;
      KeepAlive = true;
      WorkingDirectory = serverDir;
      EnvironmentVariables = {
        HOME = config.home.homeDirectory;
        HEALTH_DATA_DIR = dataDir;
      };
      StandardOutPath = logFile;
      StandardErrorPath = logFile;
    };
  };
}
