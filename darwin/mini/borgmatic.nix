# darwin/mini/borgmatic.nix
# Borgmatic backup configurations for Hetzner Storage Box
{ config, pkgs, lib, ... }:

let
  mediaVolume = "/Volumes/4tb";
  configDir = "${config.home.homeDirectory}/.config/media-server/borgmatic";

  # Common SSH command for all repos
  sshCommand = "ssh -i /ssh/id_rsa -p 23 -o IdentitiesOnly=yes -o ServerAliveInterval=60 -o StrictHostKeyChecking=yes -o UserKnownHostsFile=/ssh/known_hosts";

  # Management scripts
  borgmaticStart = pkgs.writeShellScriptBin "borgmatic-start" ''
    set -euo pipefail
    echo "Loading passphrase from 1Password..."
    BORG_PASSPHRASE=$(${pkgs._1password-cli}/bin/op read "op://Private/Hetzner Borg Backup Keys/Passphrase" 2>/dev/null)

    if [ -z "$BORG_PASSPHRASE" ]; then
      echo "ERROR: Could not get passphrase from 1Password" >&2
      exit 1
    fi

    # Write .env file for docker-compose (used by container and restarts)
    echo "BORG_PASSPHRASE=$BORG_PASSPHRASE" > "${configDir}/.env"
    chmod 600 "${configDir}/.env"

    echo "Starting Borgmatic container..."
    cd "${configDir}"
    ${pkgs.docker-compose}/bin/docker-compose up -d --build
    echo "Borgmatic started"
  '';

  borgmaticStop = pkgs.writeShellScriptBin "borgmatic-stop" ''
    set -euo pipefail
    echo "Stopping Borgmatic..."
    cd "${configDir}"
    ${pkgs.docker-compose}/bin/docker-compose down
    # Clean up .env file with passphrase
    rm -f "${configDir}/.env"
    echo "Borgmatic stopped"
  '';

  borgmaticStatus = pkgs.writeShellScriptBin "borgmatic-status" ''
    cd "${configDir}"
    ${pkgs.docker-compose}/bin/docker-compose ps
  '';

  borgmaticLogs = pkgs.writeShellScriptBin "borgmatic-logs" ''
    cd "${configDir}"
    ${pkgs.docker-compose}/bin/docker-compose logs -f
  '';

  # Get passphrase from 1Password
  getPassphrase = ''
    BORG_PASSPHRASE=$(${pkgs._1password-cli}/bin/op read "op://Private/Hetzner Borg Backup Keys/Passphrase" 2>/dev/null)
    if [ -z "$BORG_PASSPHRASE" ]; then
      echo "ERROR: Could not get passphrase from 1Password" >&2
      exit 1
    fi
    export BORG_PASSPHRASE
  '';

  # Run backup for a specific service
  borgmaticBackup = pkgs.writeShellScriptBin "borgmatic-backup" ''
    set -euo pipefail
    SERVICE="''${1:-}"

    if [ -z "$SERVICE" ]; then
      echo "Usage: borgmatic-backup <service>"
      echo "Services: immich, jellyfin, paperless, all"
      exit 1
    fi

    ${getPassphrase}

    if [ "$SERVICE" = "all" ]; then
      echo "Running all backups..."
      docker exec -e BORG_PASSPHRASE="$BORG_PASSPHRASE" -it borgmatic borgmatic --verbosity 1 --stats --progress
    else
      echo "Running $SERVICE backup..."
      docker exec -e BORG_PASSPHRASE="$BORG_PASSPHRASE" -it borgmatic borgmatic \
        --config /etc/borgmatic/config.d/$SERVICE.yaml \
        --verbosity 1 --stats --progress
    fi
  '';

  # List archives for a service
  borgmaticList = pkgs.writeShellScriptBin "borgmatic-list" ''
    set -euo pipefail
    SERVICE="''${1:-}"

    if [ -z "$SERVICE" ]; then
      echo "Usage: borgmatic-list <service>"
      echo "Services: immich, jellyfin, paperless"
      exit 1
    fi

    ${getPassphrase}

    docker exec -e BORG_PASSPHRASE="$BORG_PASSPHRASE" -it borgmatic borgmatic \
      --config /etc/borgmatic/config.d/$SERVICE.yaml \
      list
  '';

  # Check/verify backups
  borgmaticCheck = pkgs.writeShellScriptBin "borgmatic-check" ''
    set -euo pipefail
    SERVICE="''${1:-}"

    if [ -z "$SERVICE" ]; then
      echo "Usage: borgmatic-check <service>"
      echo "Services: immich, jellyfin, paperless, all"
      exit 1
    fi

    ${getPassphrase}

    if [ "$SERVICE" = "all" ]; then
      echo "Checking all repositories..."
      docker exec -e BORG_PASSPHRASE="$BORG_PASSPHRASE" -it borgmatic borgmatic check --verbosity 1
    else
      echo "Checking $SERVICE repository..."
      docker exec -e BORG_PASSPHRASE="$BORG_PASSPHRASE" -it borgmatic borgmatic \
        --config /etc/borgmatic/config.d/$SERVICE.yaml \
        check --verbosity 1
    fi
  '';

  # Info about a repository
  borgmaticInfo = pkgs.writeShellScriptBin "borgmatic-info" ''
    set -euo pipefail
    SERVICE="''${1:-}"

    if [ -z "$SERVICE" ]; then
      echo "Usage: borgmatic-info <service>"
      echo "Services: immich, jellyfin, paperless"
      exit 1
    fi

    ${getPassphrase}

    docker exec -e BORG_PASSPHRASE="$BORG_PASSPHRASE" -it borgmatic borgmatic \
      --config /etc/borgmatic/config.d/$SERVICE.yaml \
      info
  '';

  # Generate borgmatic config for a service
  # NOTE: encryption_passphrase is NOT included - it's passed via BORG_PASSPHRASE env var
  mkBorgmaticConfig = { service, subAccount, sourceDirs, excludePatterns ? [], checkArchives ? false, keepDaily ? 1, keepWeekly ? 4, keepMonthly ? 6, extraConfig ? "" }: ''
    # Borgmatic configuration for ${service}
    # Passphrase is provided via BORG_PASSPHRASE environment variable

    repositories:
      - path: ssh://REDACTED-USER-${subAccount}@REDACTED-USER-${subAccount}.your-storagebox.de:23/./borg-${service}

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

  # Management scripts
  home.packages = [
    borgmaticStart
    borgmaticStop
    borgmaticStatus
    borgmaticLogs
    borgmaticBackup
    borgmaticList
    borgmaticCheck
    borgmaticInfo
  ];

  # Borgmatic Docker Compose
  home.file."${configDir}/docker-compose.yml".text = ''
name: borgmatic

services:
  borgmatic:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: borgmatic
    restart: unless-stopped
    env_file:
      - .env
    environment:
      TZ: Europe/Berlin
      BORG_RSH: "${sshCommand}"
    volumes:
      - ./config.d:/etc/borgmatic/config.d:ro
      - ./ssh:/ssh:ro
      - ./logs:/var/log/borgmatic
      - ${mediaVolume}/immich/library/upload:/sources/immich:ro
      - ${mediaVolume}/jellyfin:/sources/jellyfin:ro
      - ${mediaVolume}/paperless:/sources/paperless:ro
  '';

  # Borgmatic crontab for scheduled backups
  home.file."${configDir}/crontab".text = ''
# Borgmatic backup schedule - run sequentially to avoid resource conflicts
# Redirect all output to log files for visibility

# Immich backup (2TB) - 2 AM daily with progress logging
0 2 * * * root borgmatic --config /etc/borgmatic/config.d/immich.yaml --verbosity 1 --stats --progress >> /var/log/borgmatic/immich-cron.log 2>&1

# Jellyfin backup - 4 AM daily
0 4 * * * root borgmatic --config /etc/borgmatic/config.d/jellyfin.yaml --verbosity 1 --stats --progress >> /var/log/borgmatic/jellyfin-cron.log 2>&1

# Paperless backup - 5 AM daily
0 5 * * * root borgmatic --config /etc/borgmatic/config.d/paperless.yaml --verbosity 1 --stats --progress >> /var/log/borgmatic/paperless-cron.log 2>&1

# Empty line required at end of crontab
  '';

  # Borgmatic Dockerfile
  home.file."${configDir}/Dockerfile".text = ''
FROM ghcr.io/borgmatic-collective/borgmatic:1.8

# Install cron
RUN apt-get update && apt-get install -y cron && rm -rf /var/lib/apt/lists/*

# Copy crontab file
COPY crontab /etc/cron.d/borgmatic-cron
RUN chmod 0644 /etc/cron.d/borgmatic-cron && crontab /etc/cron.d/borgmatic-cron

# Create log directory and start both cron and tail logs
RUN mkdir -p /var/log/borgmatic
CMD ["sh", "-c", "cron && tail -f /var/log/borgmatic/* /var/log/cron.log"]
  '';

  # launchd service for auto-start
  launchd.agents.borgmatic = {
    enable = true;
    config = {
      Label = "com.borgmatic.docker-compose";
      ProgramArguments = [
        "${borgmaticStart}/bin/borgmatic-start"
      ];
      RunAtLoad = true;
      KeepAlive = false;  # Don't restart - docker handles container lifecycle
      WorkingDirectory = configDir;
      EnvironmentVariables = {
        HOME = config.home.homeDirectory;
        PATH = "${pkgs.docker}/bin:/usr/bin:/bin";
      };
      StandardOutPath = "${config.home.homeDirectory}/.local/share/borgmatic/launchd.log";
      StandardErrorPath = "${config.home.homeDirectory}/.local/share/borgmatic/launchd.log";
    };
  };

  # Create log directory
  home.file."${config.home.homeDirectory}/.local/share/borgmatic/.keep".text = "";
}
