# darwin/mini/borgmatic.nix
# Borgmatic backup configurations for Hetzner Storage Box
{ config, pkgs, lib, ... }:

let
  miniLib = import ./lib.nix { inherit config pkgs lib; };
  inherit (miniLib) mediaVolume fetch1PasswordSecret validate1PasswordSecret mkDockerComposeYaml;

  cfg = config.services.mediaServer;
  serviceConfigDir = "${cfg.configDir}/borgmatic";

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

    # Write .env file for docker-compose
    echo "BORG_PASSPHRASE=$BORG_PASSPHRASE" > "${serviceConfigDir}/.env"
    chmod 600 "${serviceConfigDir}/.env"

    # Copy fresh config templates from nix store and substitute account ID
    echo "Generating borgmatic configs..."
    rm -f "$CONFIG_DIR"/*.yaml  # Remove old read-only files from nix store
    sed "s/HETZNER_ACCOUNT_PLACEHOLDER/$HETZNER_ACCOUNT/g" "${immichConfig}" > "$CONFIG_DIR/immich.yaml"
    sed "s/HETZNER_ACCOUNT_PLACEHOLDER/$HETZNER_ACCOUNT/g" "${jellyfinConfig}" > "$CONFIG_DIR/jellyfin.yaml"
    sed "s/HETZNER_ACCOUNT_PLACEHOLDER/$HETZNER_ACCOUNT/g" "${paperlessConfig}" > "$CONFIG_DIR/paperless.yaml"
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
    runtimeInputs = [ pkgs.docker pkgs._1password-cli ];
    text = ''
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
          --config "/etc/borgmatic/config.d/$SERVICE.yaml" \
          --verbosity 1 --stats --progress
      fi
    '';
  };

  # List archives for a service
  borgmaticList = pkgs.writeShellApplication {
    name = "borgmatic-list";
    runtimeInputs = [ pkgs.docker pkgs._1password-cli ];
    text = ''
      SERVICE="''${1:-}"

      if [ -z "$SERVICE" ]; then
        echo "Usage: borgmatic-list <service>"
        echo "Services: immich, jellyfin, paperless"
        exit 1
      fi

      ${getPassphrase}

      docker exec -e BORG_PASSPHRASE="$BORG_PASSPHRASE" -it borgmatic borgmatic \
        --config "/etc/borgmatic/config.d/$SERVICE.yaml" \
        list
    '';
  };

  # Check/verify backups
  borgmaticCheck = pkgs.writeShellApplication {
    name = "borgmatic-check";
    runtimeInputs = [ pkgs.docker pkgs._1password-cli ];
    text = ''
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
          --config "/etc/borgmatic/config.d/$SERVICE.yaml" \
          check --verbosity 1
      fi
    '';
  };

  # Info about a repository
  borgmaticInfo = pkgs.writeShellApplication {
    name = "borgmatic-info";
    runtimeInputs = [ pkgs.docker pkgs._1password-cli ];
    text = ''
      SERVICE="''${1:-}"

      if [ -z "$SERVICE" ]; then
        echo "Usage: borgmatic-info <service>"
        echo "Services: immich, jellyfin, paperless"
        exit 1
      fi

      ${getPassphrase}

      docker exec -e BORG_PASSPHRASE="$BORG_PASSPHRASE" -it borgmatic borgmatic \
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
    keepDaily ? 1,
    keepWeekly ? 4,
    keepMonthly ? 6,
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
        "${mediaVolume}/immich/library/upload:/sources/immich:ro"
        "${mediaVolume}/jellyfin:/sources/jellyfin:ro"
        "${mediaVolume}/paperless:/sources/paperless:ro"
        "/Volumes/2tb:/sources/media2tb:ro"
      ];
    };
  };

  yamlFormat = pkgs.formats.yaml { };

  # Generate files to Nix store (will be copied by activation script, not symlinked)
  immichConfig = yamlFormat.generate "immich-borgmatic.yaml" (mkBorgmaticConfig {
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
  });

  jellyfinConfig = yamlFormat.generate "jellyfin-borgmatic.yaml" (mkBorgmaticConfig {
    service = "jellyfin";
    subAccount = "sub2";
    sourceDirs = [
      "/sources/jellyfin/config"
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
    checkArchives = true;
  });

  paperlessConfig = yamlFormat.generate "paperless-borgmatic.yaml" (mkBorgmaticConfig {
    service = "paperless";
    subAccount = "sub3";
    sourceDirs = [ "/sources/paperless" ];
    excludePatterns = [
      "**/.DS_Store"
      "**/.Trash/**"
    ];
    checkArchives = true;
    keepMonthly = 12;
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

  # Helper to export BORG env vars from container's init process (cron doesn't inherit Docker env)
  exportBorgEnv = ''eval $(cat /proc/1/environ | tr "\\0" "\\n" | grep "^BORG_" | sed "s/^/export /")'';

  crontabContent = ''
    # Borgmatic backup schedule - run sequentially to avoid resource conflicts

    # Immich backup (2TB) - 2 AM daily
    0 2 * * * ${exportBorgEnv}; borgmatic --config /etc/borgmatic/config.d/immich.yaml --verbosity 1 --stats >> /var/log/borgmatic/immich-cron.log 2>&1

    # Jellyfin backup - 4 AM daily
    0 4 * * * ${exportBorgEnv}; borgmatic --config /etc/borgmatic/config.d/jellyfin.yaml --verbosity 1 --stats >> /var/log/borgmatic/jellyfin-cron.log 2>&1

    # Paperless backup - 5 AM daily
    0 5 * * * ${exportBorgEnv}; borgmatic --config /etc/borgmatic/config.d/paperless.yaml --verbosity 1 --stats >> /var/log/borgmatic/paperless-cron.log 2>&1

    # Note: media2tb is a one-time archive - run manually with: borgmatic-backup media2tb
  '';

  dockerfileContent = ''
    FROM ghcr.io/borgmatic-collective/borgmatic:1.8

    # Copy crontab file (Alpine uses /etc/crontabs/root)
    COPY crontab /etc/crontabs/root
    RUN chmod 0600 /etc/crontabs/root

    # Create log directory
    RUN mkdir -p /var/log/borgmatic
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
    $DRY_RUN_CMD mkdir -p "${serviceConfigDir}/config.d" "${serviceConfigDir}/ssh" "${serviceConfigDir}/logs"

    # Copy docker-compose.yml
    $DRY_RUN_CMD cp -f "${dockerComposeFile}" "${serviceConfigDir}/docker-compose.yml"

    # Write text files
    $DRY_RUN_CMD cat > "${serviceConfigDir}/crontab" << 'CRONTAB'
    ${crontabContent}
    CRONTAB

    $DRY_RUN_CMD cat > "${serviceConfigDir}/Dockerfile" << 'DOCKERFILE'
    ${dockerfileContent}
    DOCKERFILE

    echo "Borgmatic Docker files written"
  '';
}
