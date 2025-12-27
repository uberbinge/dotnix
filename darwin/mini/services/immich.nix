# darwin/mini/services/immich.nix
# Immich photo management - Docker Compose with launchd auto-start
{ config, pkgs, lib, username, ... }:

let
  miniLib = import ../lib.nix { inherit config pkgs lib; };
  inherit (miniLib) mediaVolume mkDockerComposeScripts mkLaunchdService fetch1PasswordSecret validate1PasswordSecret mkDockerComposeYaml;

  cfg = config.services.mediaServer;
  serviceConfigDir = "${cfg.configDir}/immich";

  # 1Password secret setup for Immich
  secretEnvSetup = ''
    echo "Loading secrets from 1Password..."
    DB_PASSWORD=${fetch1PasswordSecret { item = "immich-db"; }}
    ${validate1PasswordSecret { secretVar = "DB_PASSWORD"; item = "immich-db"; }}

    # Generate .env file
    cat > "${serviceConfigDir}/.env" << EOF
    # Auto-generated from 1Password - do not edit manually
    DB_HOSTNAME=immich_postgres
    DB_USERNAME=postgres
    DB_PASSWORD=$DB_PASSWORD
    DB_DATABASE_NAME=immich
    REDIS_HOSTNAME=immich_redis
    IMMICH_MACHINE_LEARNING_URL=http://immich-machine-learning:3003
    EOF
  '';

  scripts = mkDockerComposeScripts {
    serviceName = "immich";
    inherit serviceConfigDir;
    extraEnvSetup = secretEnvSetup;
  };

  # Docker Compose configuration as structured Nix
  composeConfig = {
    name = "immich";
    services = {
      immich-server = {
        container_name = "immich_server";
        image = "ghcr.io/immich-app/immich-server:release";
        volumes = [
          "${mediaVolume}/immich/library:/usr/src/app/upload"
          "/etc/localtime:/etc/localtime:ro"
        ];
        env_file = [ ".env" ];
        ports = [ "2283:2283" ];
        depends_on = [ "redis" "database" ];
        restart = "unless-stopped";
        healthcheck.disable = false;
      };

      immich-machine-learning = {
        container_name = "immich_machine_learning";
        image = "ghcr.io/immich-app/immich-machine-learning:release";
        volumes = [ "model-cache:/cache" ];
        env_file = [ ".env" ];
        restart = "unless-stopped";
      };

      redis = {
        container_name = "immich_redis";
        image = "docker.io/valkey/valkey:8-bookworm";
        healthcheck.test = "redis-cli ping || exit 1";
        restart = "unless-stopped";
      };

      database = {
        container_name = "immich_postgres";
        image = "ghcr.io/immich-app/postgres:14-vectorchord0.4.2-pgvectors0.2.0";
        env_file = [ ".env" ];
        environment = {
          POSTGRES_PASSWORD = "\${DB_PASSWORD}";
          POSTGRES_USER = "\${DB_USERNAME}";
          POSTGRES_DB = "\${DB_DATABASE_NAME}";
          POSTGRES_INITDB_ARGS = "--data-checksums";
        };
        volumes = [ "${mediaVolume}/immich/postgres:/var/lib/postgresql/data" ];
        healthcheck = {
          test = "pg_isready --dbname=\${DB_DATABASE_NAME} --username=\${DB_USERNAME} || exit 1";
          interval = "10s";
          timeout = "5s";
          retries = 5;
        };
        restart = "unless-stopped";
      };
    };

    volumes.model-cache = {};
  };
in
{
  home.packages = scripts.scripts;

  # Create config directory
  home.file."${serviceConfigDir}/.keep".text = "";

  # Docker Compose configuration - generated from structured Nix
  home.file."${serviceConfigDir}/docker-compose.yml".source =
    mkDockerComposeYaml "immich" composeConfig;

  # launchd service for auto-start
  launchd.agents.immich = mkLaunchdService {
    serviceName = "immich";
    startScript = scripts.start;
    inherit serviceConfigDir;
  };

  # Create log directory
  home.file."${config.home.homeDirectory}/.local/share/immich/.keep".text = "";
}
