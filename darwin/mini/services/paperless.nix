# darwin/mini/services/paperless.nix
# Paperless-ngx document management - Docker Compose with launchd auto-start
{ config, pkgs, lib, username, ... }:

let
  miniLib = import ../lib.nix { inherit config pkgs lib; };
  inherit (miniLib) mediaVolume userId groupId mkDockerComposeScripts mkLaunchdService fetch1PasswordSecret validate1PasswordSecret mkDockerComposeYaml;

  cfg = config.services.mediaServer;
  serviceConfigDir = "${cfg.configDir}/paperless";
  pgVolume =
    if cfg.paperless.useExternalPostgresDataDir
    then "${cfg.paperless.postgresDataDir}:/var/lib/postgresql/data"
    else "pgdata:/var/lib/postgresql/data";

  # 1Password secret setup for Paperless
  secretEnvSetup = ''
    echo "Loading secrets from 1Password..."
    SECRET_KEY=${fetch1PasswordSecret { item = "paperless-secret"; field = "notesPlain"; }}
    DB_PASSWORD=${fetch1PasswordSecret { item = "paperless-db"; }}
    ${validate1PasswordSecret { secretVar = "SECRET_KEY"; item = "paperless-secret"; field = "notesPlain"; }}
    ${validate1PasswordSecret { secretVar = "DB_PASSWORD"; item = "paperless-db"; }}

    # Generate .env file
    cat > "${serviceConfigDir}/.env" << EOF
    # Auto-generated from 1Password - do not edit manually
    POSTGRES_PASSWORD=$DB_PASSWORD
    PAPERLESS_SECRET_KEY=$SECRET_KEY
    PAPERLESS_OCR_LANGUAGE=eng+deu
    EOF
  '';

  scripts = mkDockerComposeScripts {
    serviceName = "paperless";
    inherit serviceConfigDir;
    extraEnvSetup = secretEnvSetup;
  };

  paperlessDbDump = pkgs.writeShellApplication {
    name = "paperless-db-dump";
    runtimeInputs = [ pkgs.coreutils pkgs.docker pkgs.gnugrep pkgs.gzip ];
    text = ''
      DUMP_DIR="${cfg.paperless.dbDumpDir}"
      mkdir -p "$DUMP_DIR"

      if ! docker ps --format '{{.Names}}' | grep -qx paperless_db; then
        echo "ERROR: paperless_db container is not running" >&2
        exit 1
      fi

      TMP_DUMP="$DUMP_DIR/paperless-latest.sql.gz.tmp"
      LATEST_DUMP="$DUMP_DIR/paperless-latest.sql.gz"
      DATED_DUMP="$DUMP_DIR/paperless-$(date +%Y-%m-%d).sql.gz"

      docker exec paperless_db pg_dump -U paperless paperless | gzip -c > "$TMP_DUMP"
      mv "$TMP_DUMP" "$LATEST_DUMP"
      cp "$LATEST_DUMP" "$DATED_DUMP"

      echo "Paperless database dump written to $LATEST_DUMP"
    '';
  };

  # Docker Compose configuration as structured Nix
  composeConfig = {
    name = "paperless";
    services = {
      broker = {
        container_name = "paperless_broker";
        image = "docker.io/library/redis:8";
        restart = "unless-stopped";
        volumes = [ "redisdata:/data" ];
      };

      db = {
        container_name = "paperless_db";
        image = "docker.io/library/postgres:17";
        restart = "unless-stopped";
        volumes = [ pgVolume ];
        environment = {
          POSTGRES_DB = "paperless";
          POSTGRES_USER = "paperless";
        };
        env_file = [ ".env" ];
      };

      webserver = {
        container_name = "paperless_webserver";
        image = "ghcr.io/paperless-ngx/paperless-ngx:latest";
        restart = "unless-stopped";
        depends_on = [ "db" "broker" ];
        ports = [ "8000:8000" ];
        volumes = [
          "${mediaVolume}/paperless/data:/usr/src/paperless/data"
          "${mediaVolume}/paperless/media:/usr/src/paperless/media"
          "${mediaVolume}/paperless/export:/usr/src/paperless/export"
          "${mediaVolume}/paperless/consume:/usr/src/paperless/consume"
        ];
        env_file = [ ".env" ];
        environment = {
          PAPERLESS_REDIS = "redis://broker:6379";
          PAPERLESS_DBHOST = "db";
          PAPERLESS_TIME_ZONE = "Europe/Berlin";
          PAPERLESS_URL = "https://${cfg.domains.paperless}";
          PAPERLESS_CSRF_TRUSTED_ORIGINS = "https://${cfg.domains.paperless}";
          USERMAP_UID = userId;
          USERMAP_GID = groupId;
        };
        healthcheck = {
          test = [ "CMD" "curl" "-f" "http://localhost:8000" ];
          interval = "30s";
          timeout = "10s";
          retries = 5;
        };
      };
    };

    volumes = { redisdata = {}; } // lib.optionalAttrs (!cfg.paperless.useExternalPostgresDataDir) {
      pgdata = {};
    };
  };
in
{
  assertions = [
    {
      assertion =
        !cfg.paperless.useExternalPostgresDataDir
        || cfg.paperless.externalPostgresMigrationConfirmed;
      message = ''
        Refusing to use ${cfg.paperless.postgresDataDir} for Paperless PostgreSQL
        until services.mediaServer.paperless.externalPostgresMigrationConfirmed
        is set to true. First migrate the existing Docker pgdata volume and
        verify a database-safe dump.
      '';
    }
  ];

  home.packages = scripts.scripts ++ [ paperlessDbDump ];

  # Create config directory
  home.file."${serviceConfigDir}/.keep".text = "";

  # Docker Compose configuration - generated from structured Nix
  home.file."${serviceConfigDir}/docker-compose.yml".source =
    mkDockerComposeYaml "paperless" composeConfig;

  # launchd service for auto-start
  launchd.agents.paperless = mkLaunchdService {
    serviceName = "paperless";
    startScript = scripts.start;
    inherit serviceConfigDir;
  };

  # Dump Postgres before the 5 AM borgmatic Paperless backup.
  launchd.agents.paperless-db-dump = {
    enable = true;
    config = {
      Label = "com.paperless.db-dump";
      ProgramArguments = [ "${paperlessDbDump}/bin/paperless-db-dump" ];
      StartCalendarInterval = [{ Hour = 4; Minute = 45; }];
      StandardOutPath = "${config.home.homeDirectory}/.local/share/paperless/db-dump.log";
      StandardErrorPath = "${config.home.homeDirectory}/.local/share/paperless/db-dump.log";
      EnvironmentVariables = {
        HOME = config.home.homeDirectory;
        PATH = "${pkgs.docker}/bin:${pkgs.gzip}/bin:/usr/bin:/bin";
      };
    };
  };

  # Create log directory
  home.file."${config.home.homeDirectory}/.local/share/paperless/.keep".text = "";
}
