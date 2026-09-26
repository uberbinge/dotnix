# darwin/mini/services/tt-coach.nix
# tt-coach - table-tennis coaching video RAG: download + ingest API and search
# Code: ~/dev/tt-coach (git). Data: ${mediaVolume}/tt-coach (media/ + tt-coach.db), backed up by borgmatic.
{ config, pkgs, lib, ... }:

let
  cfg = config.services.mediaServer;
  repoDir = "${config.home.homeDirectory}/dev/tt-coach";
  dataDir = "${cfg.mediaVolume}/tt-coach";
  logDir = "${config.home.homeDirectory}/.local/state/tt-coach";
  # Bind to Tailscale only; the API accepts download jobs and must not be reachable on the LAN.
  tailscaleIp = "100.105.137.48";
  port = "5001";
  brewPath = "/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin";
in
{
  home.file."${logDir}/.keep".text = "";

  launchd.agents.ollama = {
    enable = true;
    config = {
      Label = "dev.waqas.ollama";
      ProgramArguments = [ "/opt/homebrew/bin/ollama" "serve" ];
      RunAtLoad = true;
      KeepAlive = true;
      EnvironmentVariables = {
        HOME = config.home.homeDirectory;
        OLLAMA_HOST = "127.0.0.1:11434";
      };
      StandardOutPath = "${logDir}/ollama.log";
      StandardErrorPath = "${logDir}/ollama.log";
    };
  };

  launchd.agents.tt-coach = {
    enable = true;
    config = {
      Label = "dev.waqas.tt-coach";
      ProgramArguments = [ "${repoDir}/.venv/bin/python" "${repoDir}/webapp/server/app.py" ];
      RunAtLoad = true;
      KeepAlive = true;
      WorkingDirectory = repoDir;
      EnvironmentVariables = {
        HOME = config.home.homeDirectory;
        PATH = "${repoDir}/.venv/bin:${brewPath}";
        TT_COACH_DATA = dataDir;
        TT_COACH_HOST = tailscaleIp;
        TT_COACH_PORT = port;
      };
      StandardOutPath = "${logDir}/server.log";
      StandardErrorPath = "${logDir}/server.log";
    };
  };
}
