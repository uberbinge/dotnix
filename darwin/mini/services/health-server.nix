# darwin/mini/services/health-server.nix
# Health Export Server - Go binary syncing Apple HealthKit data
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

  # Helper scripts
  home.packages = [
    (pkgs.writeShellApplication {
      name = "health-server-status";
      runtimeInputs = [ pkgs.curl pkgs.jq ];
      text = ''
        echo "=== Service Status ==="
        launchctl list | grep health-server || echo "Not running"
        echo ""
        echo "=== Health Check ==="
        curl -s http://localhost:8080/health | jq . || echo "Server not responding"
      '';
    })

    (pkgs.writeShellApplication {
      name = "health-server-logs";
      text = ''
        tail -f "${logFile}"
      '';
    })

    (pkgs.writeShellApplication {
      name = "health-server-restart";
      text = ''
        echo "Restarting health-server..."
        launchctl stop dev.waqas.health-server 2>/dev/null || true
        launchctl start dev.waqas.health-server
        echo "Done"
      '';
    })

    (pkgs.writeShellApplication {
      name = "health-server-rebuild";
      runtimeInputs = [ pkgs.go pkgs.just ];
      text = ''
        echo "Rebuilding health-server..."
        cd "${serverDir}"
        just build
        launchctl stop dev.waqas.health-server 2>/dev/null || true
        launchctl start dev.waqas.health-server
        echo "Done"
      '';
    })
  ];
}
