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
  };
}
