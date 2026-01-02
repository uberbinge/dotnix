# darwin/mini/local-backup.nix
# Local rsync backup from 4tb to 2tb for redundancy
{ config, pkgs, lib, ... }:

let
  cfg = config.services.mediaServer;

  backupSource = "${cfg.mediaVolume}/immich";
  backupDest = "/Volumes/2tb/backup/immich";
  logDir = "${config.home.homeDirectory}/.local/share/local-backup";

  # Rsync backup script
  localBackupRun = pkgs.writeShellApplication {
    name = "local-backup-run";
    runtimeInputs = [ pkgs.rsync ];
    text = ''
      SOURCE="${backupSource}"
      DEST="${backupDest}"
      LOG_FILE="${logDir}/backup-$(date +%Y-%m-%d).log"

      echo "Starting local backup: $SOURCE -> $DEST"
      echo "Log file: $LOG_FILE"

      # Check source exists
      if [ ! -d "$SOURCE" ]; then
        echo "ERROR: Source directory does not exist: $SOURCE" | tee -a "$LOG_FILE"
        exit 1
      fi

      # Check destination drive is mounted
      if [ ! -d "/Volumes/2tb" ]; then
        echo "ERROR: Backup drive not mounted: /Volumes/2tb" | tee -a "$LOG_FILE"
        exit 1
      fi

      # Create destination directory
      mkdir -p "$DEST"

      # Run rsync with progress
      rsync -av --delete \
        --exclude=".DS_Store" \
        --exclude=".Trash" \
        --exclude="thumbs/" \
        --exclude="encoded-video/" \
        "$SOURCE/" "$DEST/" 2>&1 | tee -a "$LOG_FILE"

      echo "Backup completed at $(date)" | tee -a "$LOG_FILE"
    '';
  };

  localBackupStatus = pkgs.writeShellApplication {
    name = "local-backup-status";
    runtimeInputs = [ pkgs.findutils ];
    text = ''
      echo "=== Local Backup Status ==="
      echo ""
      echo "Source: ${backupSource}"
      echo "Destination: ${backupDest}"
      echo ""

      if [ -d "${backupDest}" ]; then
        echo "Last backup size:"
        du -sh "${backupDest}" 2>/dev/null || echo "Unable to calculate"
        echo ""
        echo "Recent logs:"
        find "${logDir}" -name "*.log" -type f -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -5 | cut -d' ' -f2- || echo "No logs found"
      else
        echo "No backup found at destination"
      fi
    '';
  };

  localBackupLogs = pkgs.writeShellApplication {
    name = "local-backup-logs";
    runtimeInputs = [ pkgs.findutils ];
    text = ''
      LOG_FILE=$(find "${logDir}" -name "*.log" -type f -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)
      if [ -n "$LOG_FILE" ]; then
        tail -100 "$LOG_FILE"
      else
        echo "No backup logs found"
      fi
    '';
  };

in
{
  home.packages = [
    localBackupRun
    localBackupStatus
    localBackupLogs
  ];

  # Create log directory
  home.file."${logDir}/.keep".text = "";

  # Daily launchd job at 1 AM (before borgmatic runs at 2 AM)
  launchd.agents.local-backup = {
    enable = true;
    config = {
      Label = "com.local-backup.rsync";
      ProgramArguments = [ "${localBackupRun}/bin/local-backup-run" ];
      StartCalendarInterval = [{ Hour = 1; Minute = 0; }];
      StandardOutPath = "${logDir}/launchd.log";
      StandardErrorPath = "${logDir}/launchd.log";
      EnvironmentVariables = {
        HOME = config.home.homeDirectory;
        PATH = "${pkgs.rsync}/bin:/usr/bin:/bin";
      };
    };
  };
}
