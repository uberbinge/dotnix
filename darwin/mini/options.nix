# darwin/mini/options.nix
# Module options for Mac Mini media server configuration
{ config, lib, ... }:

{
  options.services.mediaServer = {
    mediaVolume = lib.mkOption {
      type = lib.types.path;
      default = "/Volumes/4tb";
      description = "Path to media storage volume";
    };

    configDir = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/.config/media-server";
      description = "Base directory for media server configuration files";
    };

    userId = lib.mkOption {
      type = lib.types.str;
      default = "501";
      description = "User ID for Docker container permissions";
    };

    groupId = lib.mkOption {
      type = lib.types.str;
      default = "20";
      description = "Group ID for Docker container permissions";
    };

    onePassword = {
      vault = lib.mkOption {
        type = lib.types.str;
        default = "Private";
        description = "1Password vault for secrets";
      };
    };

    paperless = {
      postgresDataDir = lib.mkOption {
        type = lib.types.str;
        default = "${config.services.mediaServer.mediaVolume}/paperless/postgres";
        description = "Host path for Paperless PostgreSQL data after migration from the Docker named volume.";
      };

      useExternalPostgresDataDir = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Use postgresDataDir for Paperless PostgreSQL storage. Enable only after migrating the existing Docker volume.";
      };

      externalPostgresMigrationConfirmed = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Safety acknowledgement that the existing Paperless PostgreSQL data has been migrated to postgresDataDir.";
      };

      dbDumpDir = lib.mkOption {
        type = lib.types.str;
        default = "${config.services.mediaServer.mediaVolume}/paperless/db-dumps";
        description = "Host path where scheduled Paperless PostgreSQL dumps are written for borgmatic backups.";
      };
    };

    domains = {
      immich = lib.mkOption {
        type = lib.types.str;
        default = "immich.ti.waqas.dev";
        description = "Public DNS name used by Caddy for Immich.";
      };

      jellyfin = lib.mkOption {
        type = lib.types.str;
        default = "jelly.ti.waqas.dev";
        description = "Public DNS name used by Caddy for Jellyfin.";
      };

      paperless = lib.mkOption {
        type = lib.types.str;
        default = "paperless.ti.waqas.dev";
        description = "Public DNS name used by Caddy and Paperless.";
      };

      homeAssistant = lib.mkOption {
        type = lib.types.str;
        default = "home.ti.waqas.dev";
        description = "Public DNS name used by Caddy for Home Assistant.";
      };
    };
  };
}
