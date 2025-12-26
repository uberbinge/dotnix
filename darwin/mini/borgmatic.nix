# darwin/mini/borgmatic.nix
# Borgmatic backup configurations for Hetzner Storage Box
{ config, pkgs, lib, ... }:

let
  configDir = "${config.home.homeDirectory}/.config/media-server/borgmatic";

  # Common SSH command for all repos
  sshCommand = "ssh -i /ssh/id_rsa -p 23 -o IdentitiesOnly=yes -o ServerAliveInterval=60 -o StrictHostKeyChecking=yes -o UserKnownHostsFile=/ssh/known_hosts";

  # Generate borgmatic config for a service
  # NOTE: encryption_passphrase is NOT included - it's passed via BORG_PASSPHRASE env var
  mkBorgmaticConfig = { service, subAccount, sourceDirs, excludePatterns ? [], checkArchives ? false, keepDaily ? 7, keepWeekly ? 4, keepMonthly ? 6, extraConfig ? "" }: ''
    # Borgmatic configuration for ${service}
    # Passphrase is provided via BORG_PASSPHRASE environment variable

    repositories:
      - path: ssh://u491197-${subAccount}@u491197-${subAccount}.your-storagebox.de:23/./borg-${service}

    compression: zstd,6
    archive_name_format: "${service}-{now}"
    ssh_command: '${sshCommand}'

    source_directories:
    ${lib.concatMapStrings (dir: "  - ${dir}\n") sourceDirs}
    exclude_patterns:
    ${lib.concatMapStrings (pattern: "  - '${pattern}'\n") excludePatterns}
    keep_daily: ${toString keepDaily}
    keep_weekly: ${toString keepWeekly}
    keep_monthly: ${toString keepMonthly}

    checks:
      - name: repository
    ${if checkArchives then "  - name: archives" else ""}
    check_last: 3
    ${extraConfig}
  '';
in
{
  # Immich backup config
  home.file."${configDir}/config.d/immich.yaml".text = mkBorgmaticConfig {
    service = "immich";
    subAccount = "sub1";
    sourceDirs = [ "/sources/immich" ];
    excludePatterns = [
      "**/thumbs/**"
      "**/encoded-video/**"
      "**/backups/**"
      "**/.DS_Store"
      "**/.Trash/**"
    ];
  };

  # Jellyfin backup config
  home.file."${configDir}/config.d/jellyfin.yaml".text = mkBorgmaticConfig {
    service = "jellyfin";
    subAccount = "sub2";
    sourceDirs = [
      "/sources/jellyfin/jellyfin-books"
      "/sources/jellyfin/jellyfin-library"
    ];
    excludePatterns = [
      "**/.DS_Store"
      "**/.Trash/**"
      "**/cache/**"
      "**/Cache/**"
      "**/transcodes/**"
      "**/log/**"
      "**/logs/**"
      "**/temp/**"
      "**/tmp/**"
    ];
    checkArchives = true;  # Original had archives check
  };

  # Paperless backup config (longer retention - documents are critical)
  home.file."${configDir}/config.d/paperless.yaml".text = mkBorgmaticConfig {
    service = "paperless";
    subAccount = "sub3";
    sourceDirs = [ "/sources/paperless" ];
    excludePatterns = [
      "**/.DS_Store"
      "**/.Trash/**"
    ];
    checkArchives = true;  # Original had archives check
    keepMonthly = 12;      # Keep 1 year of monthly backups for documents
  };
}
