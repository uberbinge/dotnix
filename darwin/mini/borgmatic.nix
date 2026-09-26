# darwin/mini/borgmatic.nix
# Borgmatic backup configurations for Hetzner Storage Box
{ config, pkgs, lib, ... }:

let
  miniLib = import ./lib.nix { inherit config pkgs lib; };
  inherit (miniLib) mediaVolume fetch1PasswordSecret validate1PasswordSecret mkDockerComposeYaml;

  cfg = config.services.mediaServer;
  serviceConfigDir = "${cfg.configDir}/borgmatic";
  statusDir = "${serviceConfigDir}/logs/status";
  # Must match darwin/mini/services/home-assistant.nix's configDir
  haConfigDir = "${config.home.homeDirectory}/.config/home-assistant-config";
  borgmaticImage = "ghcr.io/borgmatic-collective/borgmatic:2.1@sha256:47851666598b26884bf61cf42981f602d67f8ad7b4d71c51e6a689bd685cc1f5";

  # Common SSH command for all repos
  sshCommand = "ssh -i /ssh/id_rsa -p 23 -o IdentitiesOnly=yes -o ServerAliveInterval=60 -o StrictHostKeyChecking=yes -o UserKnownHostsFile=/ssh/known_hosts";

  # Setup SSH key, known_hosts, passphrase, and generate configs from 1Password
  secretSetup = ''
    SSH_DIR="${serviceConfigDir}/ssh"
    CONFIG_DIR="${serviceConfigDir}/config.d"
    mkdir -p "$SSH_DIR" "$CONFIG_DIR"

    echo "Fetching Hetzner account ID from 1Password..."
    HETZNER_ACCOUNT=${fetch1PasswordSecret { item = "Hetzner Storage Box Account"; field = "notesPlain"; }}
    ${validate1PasswordSecret { secretVar = "HETZNER_ACCOUNT"; item = "Hetzner Storage Box Account"; field = "notesPlain"; }}
    echo "Hetzner account ID fetched"

    echo "Fetching SSH key from 1Password..."
    SSH_KEY=${fetch1PasswordSecret { item = "Hetzner Borg Backup Keys"; field = "ssh-private-key"; }}
    ${validate1PasswordSecret { secretVar = "SSH_KEY"; item = "Hetzner Borg Backup Keys"; field = "ssh-private-key"; }}
    echo "$SSH_KEY" > "$SSH_DIR/id_rsa"
    chmod 600 "$SSH_DIR/id_rsa"
    echo "SSH key fetched and secured"

    echo "Fetching known_hosts from 1Password..."
    KNOWN_HOSTS=${fetch1PasswordSecret { item = "Hetzner Storage Box Known Hosts"; field = "notesPlain"; }}
    ${validate1PasswordSecret { secretVar = "KNOWN_HOSTS"; item = "Hetzner Storage Box Known Hosts"; field = "notesPlain"; }}
    echo "$KNOWN_HOSTS" > "$SSH_DIR/known_hosts"
    chmod 600 "$SSH_DIR/known_hosts"
    echo "known_hosts fetched and secured"

    echo "Loading passphrase from 1Password..."
    BORG_PASSPHRASE=${fetch1PasswordSecret { item = "Hetzner Borg Backup Keys"; field = "Passphrase"; }}
    ${validate1PasswordSecret { secretVar = "BORG_PASSPHRASE"; item = "Hetzner Borg Backup Keys"; field = "Passphrase"; }}

    echo "Fetching Telegram credentials from 1Password..."
    TELEGRAM_BOT_TOKEN=${fetch1PasswordSecret { item = "telegram-bot"; field = "notesPlain"; }}
    ${validate1PasswordSecret { secretVar = "TELEGRAM_BOT_TOKEN"; item = "telegram-bot"; field = "notesPlain"; }}
    TELEGRAM_CHAT_ID=${fetch1PasswordSecret { item = "telegram-chat-id"; field = "notesPlain"; }}
    ${validate1PasswordSecret { secretVar = "TELEGRAM_CHAT_ID"; item = "telegram-chat-id"; field = "notesPlain"; }}
    echo "Telegram credentials fetched"

    # Write .env file for docker-compose
    {
      echo "BORG_PASSPHRASE=$BORG_PASSPHRASE"
      echo "TELEGRAM_BOT_TOKEN=$TELEGRAM_BOT_TOKEN"
      echo "TELEGRAM_CHAT_ID=$TELEGRAM_CHAT_ID"
    } > "${serviceConfigDir}/.env"
    chmod 600 "${serviceConfigDir}/.env"

    # Copy fresh config templates from nix store and substitute account ID
    echo "Generating borgmatic configs..."
    rm -f "$CONFIG_DIR"/*.yaml  # Remove old read-only files from nix store
    sed "s/HETZNER_ACCOUNT_PLACEHOLDER/$HETZNER_ACCOUNT/g" "${immichConfig}" > "$CONFIG_DIR/immich.yaml"
    sed "s/HETZNER_ACCOUNT_PLACEHOLDER/$HETZNER_ACCOUNT/g" "${jellyfinConfig}" > "$CONFIG_DIR/jellyfin.yaml"
    sed "s/HETZNER_ACCOUNT_PLACEHOLDER/$HETZNER_ACCOUNT/g" "${paperlessConfig}" > "$CONFIG_DIR/paperless.yaml"
    sed "s/HETZNER_ACCOUNT_PLACEHOLDER/$HETZNER_ACCOUNT/g" "${homeassistantConfig}" > "$CONFIG_DIR/homeassistant.yaml"
    sed "s/HETZNER_ACCOUNT_PLACEHOLDER/$HETZNER_ACCOUNT/g" "${media2tbConfig}" > "$CONFIG_DIR/media2tb.yaml"
    echo "Borgmatic configs generated"
  '';

  # Cleanup .env file with passphrase
  secretCleanup = ''
    rm -f "${serviceConfigDir}/.env"
  '';

  # Management scripts using writeShellApplication
  borgmaticStart = pkgs.writeShellApplication {
    name = "borgmatic-start";
    runtimeInputs = [ pkgs.docker pkgs._1password-cli ];
    text = ''
      ${secretSetup}
      echo "Starting Borgmatic container..."
      cd "${serviceConfigDir}"

      docker compose up -d --build
      echo "Borgmatic started"
    '';
  };

  borgmaticStop = pkgs.writeShellApplication {
    name = "borgmatic-stop";
    runtimeInputs = [ pkgs.docker ];
    text = ''
      echo "Stopping Borgmatic..."
      cd "${serviceConfigDir}"
      docker compose down
      ${secretCleanup}
      echo "Borgmatic stopped"
    '';
  };

  borgmaticStatus = pkgs.writeShellApplication {
    name = "borgmatic-status";
    runtimeInputs = [ pkgs.docker ];
    text = ''
      cd "${serviceConfigDir}"
      docker compose ps
    '';
  };

  borgmaticLogs = pkgs.writeShellApplication {
    name = "borgmatic-logs";
    runtimeInputs = [ pkgs.docker ];
    text = ''
      cd "${serviceConfigDir}"
      docker compose logs -f
    '';
  };

  # Get passphrase from 1Password
  getPassphrase = ''
    BORG_PASSPHRASE=${fetch1PasswordSecret { item = "Hetzner Borg Backup Keys"; field = "Passphrase"; }}
    ${validate1PasswordSecret { secretVar = "BORG_PASSPHRASE"; item = "Hetzner Borg Backup Keys"; field = "Passphrase"; }}
    export BORG_PASSPHRASE
  '';

  # Run backup for a specific service
  borgmaticBackup = pkgs.writeShellApplication {
    name = "borgmatic-backup";
    runtimeInputs = [ pkgs.coreutils pkgs.docker pkgs.gnugrep pkgs.gzip ];
    text = ''
      SERVICE="''${1:-}"
      STATUS_DIR="${statusDir}"

      if [ -z "$SERVICE" ]; then
        echo "Usage: borgmatic-backup <service>"
        echo "Services: immich, jellyfin, paperless, homeassistant, media2tb, all"
        exit 1
      fi

      write_status() {
        local service="$1"
        local status="$2"
        local started_epoch="$3"
        local exit_code="$4"
        local finished_epoch
        local tmp

        finished_epoch="$(date +%s)"
        mkdir -p "$STATUS_DIR"
        tmp="$STATUS_DIR/$service.status.tmp"

        {
          echo "service=$service"
          echo "status=$status"
          echo "source=manual"
          echo "started_at=$(date -d "@$started_epoch" -Iseconds)"
          echo "finished_at=$(date -d "@$finished_epoch" -Iseconds)"
          echo "started_epoch=$started_epoch"
          echo "finished_epoch=$finished_epoch"
          echo "exit_code=$exit_code"
        } > "$tmp"
        mv "$tmp" "$STATUS_DIR/$service.status"
      }

      run_borgmatic() {
        local service="$1"
        local started_epoch
        local exit_code

        started_epoch="$(date +%s)"
        echo "Running $service backup..."

        docker exec borgmatic borgmatic \
          --config "/etc/borgmatic/config.d/$service.yaml" \
          --verbosity 1 --stats --progress

        exit_code="$?"
        if [ "$exit_code" -eq 0 ]; then
          write_status "$service" success "$started_epoch" "$exit_code"
        else
          write_status "$service" failed "$started_epoch" "$exit_code"
        fi
        return "$exit_code"
      }

      dump_paperless_db() {
        DUMP_DIR="${cfg.paperless.dbDumpDir}"
        mkdir -p "$DUMP_DIR"

        if ! docker ps --format '{{.Names}}' | grep -qx paperless_db; then
          echo "ERROR: paperless_db container is not running" >&2
          exit 1
        fi

        TMP_DUMP="$DUMP_DIR/paperless-latest.sql.gz.tmp"
        LATEST_DUMP="$DUMP_DIR/paperless-latest.sql.gz"
        DATED_DUMP="$DUMP_DIR/paperless-$(date +%Y-%m-%d).sql.gz"

        echo "Creating fresh Paperless database dump..."
        docker exec paperless_db pg_dump -U paperless paperless | gzip -c > "$TMP_DUMP"
        mv "$TMP_DUMP" "$LATEST_DUMP"
        cp "$LATEST_DUMP" "$DATED_DUMP"
        echo "Paperless database dump written to $LATEST_DUMP"
      }

      if [ "$SERVICE" = "all" ]; then
        dump_paperless_db
        echo "Running all backups..."
        STARTED_EPOCH="$(date +%s)"
        docker exec borgmatic borgmatic --verbosity 1 --stats --progress
        EXIT_CODE="$?"
        for svc in immich jellyfin paperless homeassistant media2tb; do
          if [ "$EXIT_CODE" -eq 0 ]; then
            write_status "$svc" success "$STARTED_EPOCH" "$EXIT_CODE"
          else
            write_status "$svc" failed "$STARTED_EPOCH" "$EXIT_CODE"
          fi
        done
        exit "$EXIT_CODE"
      else
        if [ "$SERVICE" = "paperless" ]; then
          dump_paperless_db
        fi

        run_borgmatic "$SERVICE"
      fi
    '';
  };

  # List archives for a service
  borgmaticList = pkgs.writeShellApplication {
    name = "borgmatic-list";
    runtimeInputs = [ pkgs.docker ];
    text = ''
      SERVICE="''${1:-}"

      if [ -z "$SERVICE" ]; then
        echo "Usage: borgmatic-list <service>"
        echo "Services: immich, jellyfin, paperless, homeassistant"
        exit 1
      fi

      docker exec -it borgmatic borgmatic \
        --config "/etc/borgmatic/config.d/$SERVICE.yaml" \
        list
    '';
  };

  # Check/verify backups
  borgmaticCheck = pkgs.writeShellApplication {
    name = "borgmatic-check";
    runtimeInputs = [ pkgs.docker ];
    text = ''
      SERVICE="''${1:-}"

      if [ -z "$SERVICE" ]; then
        echo "Usage: borgmatic-check <service>"
        echo "Services: immich, jellyfin, paperless, homeassistant, all"
        exit 1
      fi

      if [ "$SERVICE" = "all" ]; then
        echo "Checking all repositories..."
        docker exec -it borgmatic borgmatic check --verbosity 1
      else
        echo "Checking $SERVICE repository..."
        docker exec -it borgmatic borgmatic \
          --config "/etc/borgmatic/config.d/$SERVICE.yaml" \
          check --verbosity 1
      fi
    '';
  };

  # Info about a repository
  borgmaticInfo = pkgs.writeShellApplication {
    name = "borgmatic-info";
    runtimeInputs = [ pkgs.docker ];
    text = ''
      SERVICE="''${1:-}"

      if [ -z "$SERVICE" ]; then
        echo "Usage: borgmatic-info <service>"
        echo "Services: immich, jellyfin, paperless, homeassistant"
        exit 1
      fi

      docker exec -it borgmatic borgmatic \
        --config "/etc/borgmatic/config.d/$SERVICE.yaml" \
        info
    '';
  };

  # Generate borgmatic config for a service
  # Uses HETZNER_ACCOUNT_PLACEHOLDER which is replaced at runtime with real account ID from 1Password
  mkBorgmaticConfig = {
    service,
    subAccount,
    sourceDirs,
    excludePatterns ? [],
    checkArchives ? false,
    keepDaily ? 7,
    keepWeekly ? 4,
    keepMonthly ? 6,
    commands ? [],
  }: {
    repositories = [{
      path = "ssh://HETZNER_ACCOUNT_PLACEHOLDER-${subAccount}@HETZNER_ACCOUNT_PLACEHOLDER-${subAccount}.your-storagebox.de:23/./borg-${service}";
    }];
    compression = "zstd,6";
    archive_name_format = "${service}-{now}";
    ssh_command = sshCommand;
    source_directories = sourceDirs;
    exclude_patterns = excludePatterns;
    keep_daily = keepDaily;
    keep_weekly = keepWeekly;
    keep_monthly = keepMonthly;
    checks = [{ name = "repository"; }] ++ lib.optionals checkArchives [{ name = "archives"; }];
    check_last = 3;
  } // lib.optionalAttrs (commands != []) {
    inherit commands;
  };

  # Docker Compose configuration as structured Nix
  composeConfig = {
    name = "borgmatic";
    services.borgmatic = {
      build = {
        context = ".";
        dockerfile = "Dockerfile";
      };
      container_name = "borgmatic";
      restart = "unless-stopped";
      env_file = [ ".env" ];
      environment = {
        TZ = "Europe/Berlin";
        BORG_RSH = sshCommand;
      };
      volumes = [
        "./config.d:/etc/borgmatic/config.d:ro"
        "./ssh:/ssh:ro"
        "./logs:/var/log/borgmatic"
        "${mediaVolume}/immich/library:/sources/immich:ro"
        "${mediaVolume}/immich/postgres:/sources/immich-postgres:ro"
        "${mediaVolume}/jellyfin:/sources/jellyfin:ro"
        "${mediaVolume}/paperless:/sources/paperless:ro"
        "${cfg.paperless.dbDumpDir}:/sources/paperless-db-dumps:ro"
        "${haConfigDir}:/sources/homeassistant:ro"
        "/Volumes/2tb:/sources/media2tb:ro"
      ];
    };
  };

  yamlFormat = pkgs.formats.yaml { };

  # Generate files to Nix store (will be copied by activation script, not symlinked)
  immichConfig = yamlFormat.generate "immich-borgmatic.yaml" (mkBorgmaticConfig {
    service = "immich";
    subAccount = "sub1";
    sourceDirs = [
      "/sources/immich"
      "/sources/immich-postgres"
      "/tmp/immich-db-latest"
    ];
    excludePatterns = [
      "**/thumbs/**"
      "**/encoded-video/**"
      "**/backups/**"
      "**/.DS_Store"
      "**/.Trash/**"
    ];
    checkArchives = true;
    commands = [
      {
        before = "repository";
        when = [ "create" ];
        run = [
          "mkdir -p /tmp/immich-db-latest && latest=$(find /sources/immich/backups -name '*.sql.gz' -type f 2>/dev/null | sort | tail -1) && if [ -n \"$latest\" ]; then cp \"$latest\" /tmp/immich-db-latest/; else echo 'No Immich SQL dump found under /sources/immich/backups'; fi"
        ];
      }
      {
        after = "repository";
        when = [ "create" ];
        run = [ "rm -rf /tmp/immich-db-latest" ];
      }
    ];
  });

  jellyfinConfig = yamlFormat.generate "jellyfin-borgmatic.yaml" (mkBorgmaticConfig {
    service = "jellyfin";
    subAccount = "sub2";
    sourceDirs = [
      "/sources/jellyfin/config"
      "/sources/jellyfin/jellyfin-books"
      "/sources/jellyfin/jellyfin-library"
      "/sources/jellyfin/us"
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
    checkArchives = true;
  });

  paperlessConfig = yamlFormat.generate "paperless-borgmatic.yaml" (mkBorgmaticConfig {
    service = "paperless";
    subAccount = "sub3";
    sourceDirs = [
      "/sources/paperless"
      "/sources/paperless-db-dumps"
    ];
    excludePatterns = [
      "**/.DS_Store"
      "**/.Trash/**"
    ];
    checkArchives = true;
    keepMonthly = 12;
  });

  homeassistantConfig = yamlFormat.generate "homeassistant-borgmatic.yaml" (mkBorgmaticConfig {
    service = "homeassistant";
    subAccount = "sub4";
    sourceDirs = [ "/sources/homeassistant" ];
    excludePatterns = [
      "**/.DS_Store"
      "**/.Trash/**"
      "**/.storage/*.corrupt.*"
    ];
    checkArchives = true;
  });

  # 2TB drive backup - ONE-TIME ARCHIVE (not scheduled, keep forever)
  media2tbConfig = yamlFormat.generate "media2tb-borgmatic.yaml" (mkBorgmaticConfig {
    service = "media2tb";
    subAccount = "sub5";
    sourceDirs = [ "/sources/media2tb" ];
    excludePatterns = [
      "**/.DS_Store"
      "**/.Trash/**"
      "**/.Spotlight-V100/**"
      "**/.fseventsd/**"
    ];
    # Keep everything - no pruning for one-time archive
    keepDaily = 9999;
    keepWeekly = 0;
    keepMonthly = 0;
  });

  dockerComposeFile = mkDockerComposeYaml "borgmatic" composeConfig;

  # Helper to export env vars from container's init process (cron doesn't inherit Docker env)
  exportBorgEnv = ''eval $(cat /proc/1/environ | tr "\\0" "\\n" | grep "^BORG_" | sed "s/^/export /")'';
  exportTelegramEnv = ''eval $(cat /proc/1/environ | tr "\\0" "\\n" | grep "^TELEGRAM_" | sed "s/^/export /")'';

  # Note: Alpine/BusyBox crontab doesn't use username field
  crontabContent = ''
    # Borgmatic backup schedule - run sequentially to avoid resource conflicts

    # Immich backup (2TB) - 2 AM daily
    0 2 * * * ${exportBorgEnv}; /scripts/backup-runner.sh immich

    # Jellyfin backup - 4 AM daily
    0 4 * * * ${exportBorgEnv}; /scripts/backup-runner.sh jellyfin

    # Paperless backup - 5 AM daily
    0 5 * * * ${exportBorgEnv}; /scripts/backup-runner.sh paperless

    # Home Assistant config backup - 5:10 AM daily (after paperless, which finishes in seconds)
    10 5 * * * ${exportBorgEnv}; /scripts/backup-runner.sh homeassistant

    # Daily backup status report via Telegram - 9 AM
    0 9 * * * ${exportTelegramEnv}; /scripts/backup-status.sh >> /var/log/borgmatic/status-report.log 2>&1

    # Note: media2tb is a one-time archive - run manually with: borgmatic-backup media2tb
  '';

  dockerfileContent = ''
    FROM ${borgmaticImage}

    # Install curl for Telegram notifications
    RUN apk add --no-cache curl

    # Copy crontab file (Alpine uses /etc/crontabs/root)
    COPY crontab /etc/crontabs/root
    RUN chmod 0600 /etc/crontabs/root

    # Copy notification script
    COPY scripts/backup-status.sh /scripts/backup-status.sh
    RUN chmod +x /scripts/backup-status.sh

    # Copy backup runner script
    COPY scripts/backup-runner.sh /scripts/backup-runner.sh
    RUN chmod +x /scripts/backup-runner.sh

    # Create log directory
    RUN mkdir -p /var/log/borgmatic/status
  '';

  backupRunnerScript = ''
    #!/bin/sh
    # Runs one borgmatic config and writes a small status file for dashboards.

    SERVICE="$1"
    CONFIG="/etc/borgmatic/config.d/$SERVICE.yaml"
    LOG="/var/log/borgmatic/$SERVICE-cron.log"
    STATUS_DIR="/var/log/borgmatic/status"

    if [ -z "$SERVICE" ] || [ ! -f "$CONFIG" ]; then
      echo "Usage: backup-runner.sh <service>" >&2
      exit 64
    fi

    mkdir -p "$STATUS_DIR"
    STARTED_EPOCH="$(date +%s)"
    STARTED_AT="$(date -Iseconds)"

    borgmatic --config "$CONFIG" --verbosity 1 --stats >> "$LOG" 2>&1
    EXIT_CODE="$?"

    FINISHED_EPOCH="$(date +%s)"
    FINISHED_AT="$(date -Iseconds)"
    TMP="$STATUS_DIR/$SERVICE.status.tmp"

    if [ "$EXIT_CODE" -eq 0 ]; then
      STATUS="success"
    else
      STATUS="failed"
    fi

    {
      echo "service=$SERVICE"
      echo "status=$STATUS"
      echo "source=cron"
      echo "started_at=$STARTED_AT"
      echo "finished_at=$FINISHED_AT"
      echo "started_epoch=$STARTED_EPOCH"
      echo "finished_epoch=$FINISHED_EPOCH"
      echo "exit_code=$EXIT_CODE"
    } > "$TMP"
    mv "$TMP" "$STATUS_DIR/$SERVICE.status"

    exit "$EXIT_CODE"
  '';

  # Backup status notification script for Telegram
  backupStatusScript = ''
    #!/bin/bash
    # Backup Status Notification Script
    # Sends daily Telegram report of backup status for all services

    set -e

    # Telegram API function
    send_telegram() {
        local message="$1"
        curl -s -X POST "https://api.telegram.org/bot''${TELEGRAM_BOT_TOKEN}/sendMessage" \
            -d "chat_id=''${TELEGRAM_CHAT_ID}" \
            -d "text=''${message}" \
            -d "parse_mode=HTML" > /dev/null
    }

    # Check if backup ran today for a given config
    check_backup_status() {
        local config="$1"

        # Get the latest archive info using borgmatic
        local latest_info=$(borgmatic list --config "$config" --last 1 2>/dev/null | tail -1)

        if [ -z "$latest_info" ]; then
            echo "FAIL"
            return
        fi

        # Extract date from archive line
        local archive_date=$(echo "$latest_info" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' | head -1)
        local today=$(date +%Y-%m-%d)

        if [ "$archive_date" = "$today" ]; then
            echo "OK"
        else
            echo "STALE:$archive_date"
        fi
    }

    # Config paths
    IMMICH_CONFIG="/etc/borgmatic/config.d/immich.yaml"
    JELLYFIN_CONFIG="/etc/borgmatic/config.d/jellyfin.yaml"
    PAPERLESS_CONFIG="/etc/borgmatic/config.d/paperless.yaml"
    HOMEASSISTANT_CONFIG="/etc/borgmatic/config.d/homeassistant.yaml"

    # Check each service
    immich_status=$(check_backup_status "$IMMICH_CONFIG")
    jellyfin_status=$(check_backup_status "$JELLYFIN_CONFIG")
    paperless_status=$(check_backup_status "$PAPERLESS_CONFIG")
    homeassistant_status=$(check_backup_status "$HOMEASSISTANT_CONFIG")

    # Build status message
    today=$(date +"%Y-%m-%d")
    message="<b>Backup Status Report</b>
    ''${today}

    "

    failures=0

    # Immich status
    if [ "$immich_status" = "OK" ]; then
        message+="✅ Immich: OK
    "
    elif [[ "$immich_status" == STALE:* ]]; then
        last_date="''${immich_status#STALE:}"
        message+="⚠️ Immich: Stale (last: ''${last_date})
    "
        ((failures++)) || true
    else
        message+="❌ Immich: FAILED
    "
        ((failures++)) || true
    fi

    # Jellyfin status
    if [ "$jellyfin_status" = "OK" ]; then
        message+="✅ Jellyfin: OK
    "
    elif [[ "$jellyfin_status" == STALE:* ]]; then
        last_date="''${jellyfin_status#STALE:}"
        message+="⚠️ Jellyfin: Stale (last: ''${last_date})
    "
        ((failures++)) || true
    else
        message+="❌ Jellyfin: FAILED
    "
        ((failures++)) || true
    fi

    # Paperless status
    if [ "$paperless_status" = "OK" ]; then
        message+="✅ Paperless: OK
    "
    elif [[ "$paperless_status" == STALE:* ]]; then
        last_date="''${paperless_status#STALE:}"
        message+="⚠️ Paperless: Stale (last: ''${last_date})
    "
        ((failures++)) || true
    else
        message+="❌ Paperless: FAILED
    "
        ((failures++)) || true
    fi

    # Home Assistant status
    if [ "$homeassistant_status" = "OK" ]; then
        message+="✅ Home Assistant: OK
    "
    elif [[ "$homeassistant_status" == STALE:* ]]; then
        last_date="''${homeassistant_status#STALE:}"
        message+="⚠️ Home Assistant: Stale (last: ''${last_date})
    "
        ((failures++)) || true
    else
        message+="❌ Home Assistant: FAILED
    "
        ((failures++)) || true
    fi

    # Add summary
    if [ "$failures" -eq 0 ]; then
        message+="
    All backups completed successfully!"
    else
        message+="
    ⚠️ ''${failures} backup(s) need attention"
    fi

    # Send notification
    send_telegram "$message"

    echo "[$(date)] Status report sent to Telegram"
  '';

in
{
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

  # launchd service for auto-start
  launchd.agents.borgmatic = {
    enable = true;
    config = {
      Label = "com.borgmatic.docker-compose";
      ProgramArguments = [ "${borgmaticStart}/bin/borgmatic-start" ];
      RunAtLoad = true;
      KeepAlive = false;
      WorkingDirectory = serviceConfigDir;
      EnvironmentVariables = {
        HOME = config.home.homeDirectory;
        PATH = "${pkgs.docker}/bin:/usr/bin:/bin";
      };
      StandardOutPath = "${config.home.homeDirectory}/.local/share/borgmatic/launchd.log";
      StandardErrorPath = "${config.home.homeDirectory}/.local/share/borgmatic/launchd.log";
    };
  };

  # Create log directory (this one can stay as home.file - not Docker related)
  home.file."${config.home.homeDirectory}/.local/share/borgmatic/.keep".text = "";

  # Write Docker-related files directly via activation script (no symlinks)
  # This avoids the symlink-to-real-file dance that conflicts with Home Manager
  # Note: YAML configs are generated at runtime by borgmatic-start (with secret substitution)
  home.activation.borgmaticWriteFiles = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    echo "Writing borgmatic Docker files..."
    $DRY_RUN_CMD mkdir -p "${serviceConfigDir}/config.d" "${serviceConfigDir}/ssh" "${serviceConfigDir}/logs/status" "${serviceConfigDir}/scripts"

    # Copy docker-compose.yml
    $DRY_RUN_CMD cp -f "${dockerComposeFile}" "${serviceConfigDir}/docker-compose.yml"

    # Write text files
    $DRY_RUN_CMD cat > "${serviceConfigDir}/crontab" << 'CRONTAB'
    ${crontabContent}
    CRONTAB

    $DRY_RUN_CMD cat > "${serviceConfigDir}/Dockerfile" << 'DOCKERFILE'
    ${dockerfileContent}
    DOCKERFILE

    $DRY_RUN_CMD cat > "${serviceConfigDir}/scripts/backup-status.sh" << 'SCRIPT'
    ${backupStatusScript}
    SCRIPT
    $DRY_RUN_CMD chmod +x "${serviceConfigDir}/scripts/backup-status.sh"

    $DRY_RUN_CMD cat > "${serviceConfigDir}/scripts/backup-runner.sh" << 'SCRIPT'
    ${backupRunnerScript}
    SCRIPT
    $DRY_RUN_CMD chmod +x "${serviceConfigDir}/scripts/backup-runner.sh"

    echo "Borgmatic Docker files written"
  '';
}
