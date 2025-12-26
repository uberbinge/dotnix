# darwin/mini/services/immich.nix
# Immich photo management - Docker Compose with launchd auto-start
{ config, pkgs, lib, username, ... }:

let
  mediaVolume = "/Volumes/4tb";
  configDir = "${config.home.homeDirectory}/.config/media-server/immich";
  composeFile = "${configDir}/docker-compose.yml";

  # Script to generate .env from 1Password and start Immich
  immichStart = pkgs.writeShellScriptBin "immich-start" ''
    set -euo pipefail

    echo "Loading secrets from 1Password..."
    DB_PASSWORD=$(${pkgs._1password-cli}/bin/op read "op://Private/immich-db/password" 2>/dev/null)

    if [ -z "$DB_PASSWORD" ]; then
      echo "ERROR: Failed to load Immich DB password from 1Password" >&2
      echo "Ensure 'immich-db' item exists in Private vault with 'password' field" >&2
      exit 1
    fi

    # Generate .env file
    cat > "${configDir}/.env" << EOF
    # Auto-generated from 1Password - do not edit manually
    DB_HOSTNAME=immich_postgres
    DB_USERNAME=postgres
    DB_PASSWORD=$DB_PASSWORD
    DB_DATABASE_NAME=immich
    REDIS_HOSTNAME=immich_redis
    IMMICH_MACHINE_LEARNING_URL=http://immich-machine-learning:3003
    EOF

    echo "Starting Immich..."
    cd "${configDir}"
    ${pkgs.docker-compose}/bin/docker-compose up -d

    echo "Immich started successfully"
  '';

  immichStop = pkgs.writeShellScriptBin "immich-stop" ''
    set -euo pipefail
    echo "Stopping Immich..."
    cd "${configDir}"
    ${pkgs.docker-compose}/bin/docker-compose down
    echo "Immich stopped"
  '';

  immichLogs = pkgs.writeShellScriptBin "immich-logs" ''
    cd "${configDir}"
    ${pkgs.docker-compose}/bin/docker-compose logs -f "''${1:-}"
  '';

  immichStatus = pkgs.writeShellScriptBin "immich-status" ''
    cd "${configDir}"
    ${pkgs.docker-compose}/bin/docker-compose ps
  '';

  immichRestart = pkgs.writeShellScriptBin "immich-restart" ''
    ${immichStop}/bin/immich-stop
    ${immichStart}/bin/immich-start
  '';

  immichUpdate = pkgs.writeShellScriptBin "immich-update" ''
    set -euo pipefail
    echo "Pulling latest Immich images..."
    cd "${configDir}"
    ${pkgs.docker-compose}/bin/docker-compose pull
    echo "Restarting with new images..."
    ${immichRestart}/bin/immich-restart
    echo "Immich updated successfully"
  '';
in
{
  home.packages = [
    immichStart
    immichStop
    immichLogs
    immichStatus
    immichRestart
    immichUpdate
  ];

  # Create config directory
  home.file."${configDir}/.keep".text = "";

  # Docker Compose configuration
  home.file."${configDir}/docker-compose.yml".text = ''
    name: immich

    services:
      immich-server:
        container_name: immich_server
        image: ghcr.io/immich-app/immich-server:release
        volumes:
          - ${mediaVolume}/immich/library/upload:/usr/src/app/upload
          - /etc/localtime:/etc/localtime:ro
        env_file:
          - .env
        ports:
          - "2283:2283"
        depends_on:
          - redis
          - database
        restart: unless-stopped
        healthcheck:
          disable: false

      immich-machine-learning:
        container_name: immich_machine_learning
        image: ghcr.io/immich-app/immich-machine-learning:release
        volumes:
          - model-cache:/cache
        env_file:
          - .env
        restart: unless-stopped

      redis:
        container_name: immich_redis
        image: redis:6.2-alpine
        healthcheck:
          test: redis-cli ping || exit 1
        restart: unless-stopped

      database:
        container_name: immich_postgres
        image: tensorchord/pgvecto-rs:pg14-v0.2.0
        env_file:
          - .env
        environment:
          POSTGRES_PASSWORD: ''${DB_PASSWORD}
          POSTGRES_USER: ''${DB_USERNAME}
          POSTGRES_DB: ''${DB_DATABASE_NAME}
          POSTGRES_INITDB_ARGS: '--data-checksums'
        volumes:
          - ${mediaVolume}/immich/postgres:/var/lib/postgresql/data
        healthcheck:
          test: pg_isready --dbname=''${DB_DATABASE_NAME} --username=''${DB_USERNAME} || exit 1
          interval: 10s
          timeout: 5s
          retries: 5
        restart: unless-stopped

    volumes:
      model-cache:
  '';

  # launchd service for auto-start
  launchd.agents.immich = {
    enable = true;
    config = {
      Label = "com.immich.docker-compose";
      ProgramArguments = [
        "${immichStart}/bin/immich-start"
      ];
      RunAtLoad = true;
      KeepAlive = false;  # Don't restart - docker handles container lifecycle
      WorkingDirectory = configDir;
      EnvironmentVariables = {
        HOME = config.home.homeDirectory;
        PATH = "${pkgs.docker}/bin:${pkgs._1password-cli}/bin:/usr/bin:/bin";
      };
      StandardOutPath = "${config.home.homeDirectory}/.local/share/immich/launchd.log";
      StandardErrorPath = "${config.home.homeDirectory}/.local/share/immich/launchd.log";
    };
  };

  # Create log directory
  home.file."${config.home.homeDirectory}/.local/share/immich/.keep".text = "";
}
