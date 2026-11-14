# darwin/mini/services/matter-server.nix
# Matter Server (matterjs-server) - native on macOS, not Docker: Thread/Matter needs the
# LAN's IPv6 link-local multicast and the border router's routes, which containers can't see.
# Home Assistant (Docker) connects to ws://host.docker.internal:5580/ws.
{ config, pkgs, lib, ... }:

let
  cfg = config.services.mediaServer;
  version = "1.5.5";
  dataDir = "${cfg.configDir}/matter-server";
  appDir = "${config.home.homeDirectory}/.local/share/matter-server/app";
  logFile = "${config.home.homeDirectory}/.local/share/matter-server/server.log";

  start = pkgs.writeShellApplication {
    name = "matter-server-start";
    runtimeInputs = [ pkgs.nodejs_24 ];
    text = ''
      pkg="${appDir}/node_modules/matter-server/package.json"
      installed="$(node -p "require('$pkg').version" 2>/dev/null || true)"
      if [ "$installed" != "${version}" ]; then
        echo "Installing matter-server ${version} (found: ''${installed:-none})"
        mkdir -p "${appDir}"
        npm install --prefix "${appDir}" --no-audit --no-fund --omit=dev "matter-server@${version}"
      fi
      mkdir -p "${dataDir}"
      # Loopback only: the WebSocket API has no auth, and HA reaches it via host.docker.internal.
      # en1 is the Mini's Wi-Fi, where the Thread border router's routes are learned.
      exec node "${appDir}/node_modules/matter-server/dist/esm/bin.js" \
        --storage-path "${dataDir}" \
        --listen-address 127.0.0.1 \
        --primary-interface en1
    '';
  };
in
{
  home.packages = [ start ];

  home.file."${dataDir}/.keep".text = "";

  launchd.agents.matter-server = {
    enable = true;
    config = {
      Label = "com.matter-server";
      ProgramArguments = [ "${start}/bin/matter-server-start" ];
      RunAtLoad = true;
      KeepAlive = true;
      EnvironmentVariables.HOME = config.home.homeDirectory;
      StandardOutPath = logFile;
      StandardErrorPath = logFile;
    };
  };
}
