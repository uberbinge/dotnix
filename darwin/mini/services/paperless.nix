# darwin/mini/services/paperless.nix
# Paperless-ngx document management - Docker Compose with launchd auto-start
{ config, pkgs, lib, username, ... }:

let
  mediaVolume = "/Volumes/4tb";
  configDir = "${config.home.homeDirectory}/.config/media-server/paperless";
  composeFile = "${configDir}/docker-compose.yml";

  # Script to generate .env from 1Password and start Paperless
  paperlessStart = pkgs.writeShellScriptBin "paperless-start" ''
    set -euo pipefail

    echo "Loading secrets from 1Password..."
    SECRET_KEY=$(${pkgs._1password-cli}/bin/op read "op://Private/paperless-secret/notesPlain" 2>/dev/null)
    DB_PASSWORD=$(${pkgs._1password-cli}/bin/op read "op://Private/paperless-db/password" 2>/dev/null)

    if [ -z "$SECRET_KEY" ]; then
      echo "ERROR: Failed to load Paperless secret key from 1Password" >&2
      echo "Ensure 'paperless-secret' item exists in Private vault with secret in 'notesPlain' field" >&2
      exit 1
    fi
    if [ -z "$DB_PASSWORD" ]; then
      echo "ERROR: Failed to load Paperless DB password from 1Password" >&2
      echo "Ensure 'paperless-db' item exists in Private vault with 'password' field" >&2
      exit 1
    fi

    # Generate .env file
    cat > "${configDir}/.env" << EOF
    # Auto-generated from 1Password - do not edit manually
    POSTGRES_PASSWORD=$DB_PASSWORD
    PAPERLESS_SECRET_KEY=$SECRET_KEY
    PAPERLESS_OCR_LANGUAGE=eng+deu
    EOF

    echo "Starting Paperless..."
    cd "${configDir}"
    ${pkgs.docker-compose}/bin/docker-compose up -d

    echo "Paperless started successfully"
  '';

  paperlessStop = pkgs.writeShellScriptBin "paperless-stop" ''
    set -euo pipefail
    echo "Stopping Paperless..."
    cd "${configDir}"
    ${pkgs.docker-compose}/bin/docker-compose down
    echo "Paperless stopped"
  '';

  paperlessLogs = pkgs.writeShellScriptBin "paperless-logs" ''
    cd "${configDir}"
    ${pkgs.docker-compose}/bin/docker-compose logs -f "''${1:-}"
  '';

  paperlessStatus = pkgs.writeShellScriptBin "paperless-status" ''
    cd "${configDir}"
    ${pkgs.docker-compose}/bin/docker-compose ps
  '';

  paperlessRestart = pkgs.writeShellScriptBin "paperless-restart" ''
    ${paperlessStop}/bin/paperless-stop
    ${paperlessStart}/bin/paperless-start
  '';

  paperlessUpdate = pkgs.writeShellScriptBin "paperless-update" ''
    set -euo pipefail
    echo "Pulling latest Paperless images..."
    cd "${configDir}"
    ${pkgs.docker-compose}/bin/docker-compose pull
    echo "Restarting with new images..."
    ${paperlessRestart}/bin/paperless-restart
    echo "Paperless updated successfully"
  '';
in
{
  home.packages = [
    paperlessStart
    paperlessStop
    paperlessLogs
    paperlessStatus
    paperlessRestart
    paperlessUpdate
  ];

  # Create config directory
  home.file."${configDir}/.keep".text = "";

  # Docker Compose configuration
  home.file."${configDir}/docker-compose.yml".text = ''
    name: paperless

    services:
      broker:
        container_name: paperless_broker
        image: docker.io/library/redis:7
        restart: unless-stopped
        volumes:
          - redisdata:/data

      db:
        container_name: paperless_db
        image: docker.io/library/postgres:17
        restart: unless-stopped
        volumes:
          - pgdata:/var/lib/postgresql/data
        environment:
          POSTGRES_DB: paperless
          POSTGRES_USER: paperless
        env_file:
          - .env

      webserver:
        container_name: paperless_webserver
        image: ghcr.io/paperless-ngx/paperless-ngx:latest
        restart: unless-stopped
        depends_on:
          - db
          - broker
        ports:
          - "8000:8000"
        volumes:
          - ${mediaVolume}/paperless/data:/usr/src/paperless/data
          - ${mediaVolume}/paperless/media:/usr/src/paperless/media
          - ${mediaVolume}/paperless/export:/usr/src/paperless/export
          - ${mediaVolume}/paperless/consume:/usr/src/paperless/consume
        env_file:
          - .env
        environment:
          PAPERLESS_REDIS: redis://broker:6379
          PAPERLESS_DBHOST: db
          PAPERLESS_TIME_ZONE: Europe/Berlin
          USERMAP_UID: 501
          USERMAP_GID: 20
        healthcheck:
          test: ["CMD", "curl", "-f", "http://localhost:8000"]
          interval: 30s
          timeout: 10s
          retries: 5

    volumes:
      redisdata:
      pgdata:
  '';

  # launchd service for auto-start
  launchd.agents.paperless = {
    enable = true;
    config = {
      Label = "com.paperless.docker-compose";
      ProgramArguments = [
        "${paperlessStart}/bin/paperless-start"
      ];
      RunAtLoad = true;
      KeepAlive = false;
      WorkingDirectory = configDir;
      EnvironmentVariables = {
        HOME = config.home.homeDirectory;
        PATH = "${pkgs.docker}/bin:${pkgs._1password-cli}/bin:/usr/bin:/bin";
      };
      StandardOutPath = "${config.home.homeDirectory}/.local/share/paperless/launchd.log";
      StandardErrorPath = "${config.home.homeDirectory}/.local/share/paperless/launchd.log";
    };
  };

  # Create log directory
  home.file."${config.home.homeDirectory}/.local/share/paperless/.keep".text = "";
}
