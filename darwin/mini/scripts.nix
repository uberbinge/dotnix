# darwin/mini/scripts.nix
# Helper scripts for Mac Mini media server management
{ config, pkgs, lib, ... }:

let
  configDir = "${config.home.homeDirectory}/.config/media-server";
in
{
  home.packages = with pkgs; [
    # Media server management script
    (writeShellScriptBin "media-server" ''
      #!/bin/bash
      set -e

      CONFIG_DIR="${configDir}"
      SERVICES="immich jellyfin paperless borgmatic"

      # Colors for output
      RED='\033[0;31m'
      GREEN='\033[0;32m'
      YELLOW='\033[1;33m'
      NC='\033[0m' # No Color

      log_info() { echo -e "''${GREEN}[INFO]''${NC} $1"; }
      log_warn() { echo -e "''${YELLOW}[WARN]''${NC} $1"; }
      log_error() { echo -e "''${RED}[ERROR]''${NC} $1"; }

      # Check if 1Password CLI is available and signed in
      check_op() {
        if ! command -v op &> /dev/null; then
          log_error "1Password CLI (op) not found. Install with: brew install 1password-cli"
          exit 1
        fi
        if ! op account get &> /dev/null; then
          log_warn "Not signed in to 1Password. Run: op signin"
          return 1
        fi
        return 0
      }

      # Inject secrets from 1Password into env files and fetch SSH key
      inject_secrets() {
        log_info "Injecting secrets from 1Password..."

        if ! check_op; then
          log_error "Cannot inject secrets - 1Password not available"
          exit 1
        fi

        # Fetch SSH key for borgmatic
        SSH_DIR="$CONFIG_DIR/borgmatic/ssh"
        mkdir -p "$SSH_DIR"
        log_info "Fetching SSH key from 1Password..."
        op document get "ssh-private-key" --vault="Private" --out-file="$SSH_DIR/id_rsa" 2>/dev/null || \
          op read "op://Private/Hetzner Borg Backup Keys/ssh-private-key" > "$SSH_DIR/id_rsa" 2>/dev/null
        if [ -f "$SSH_DIR/id_rsa" ]; then
          chmod 600 "$SSH_DIR/id_rsa"
          log_info "SSH key fetched and secured"
        else
          log_warn "Could not fetch SSH key from 1Password - borgmatic may fail"
        fi

        # Fetch known_hosts if available
        op document get "known-hosts" --vault="Private" --out-file="$SSH_DIR/known_hosts" 2>/dev/null || true

        # Immich DB password
        if [ -f "$CONFIG_DIR/immich/.env.template" ]; then
          IMMICH_DB_PASS=$(op read "op://Private/immich-db/password" 2>/dev/null || echo "")
          if [ -n "$IMMICH_DB_PASS" ]; then
            sed "s/__IMMICH_DB_PASSWORD__/$IMMICH_DB_PASS/" \
              "$CONFIG_DIR/immich/.env.template" > "$CONFIG_DIR/immich/.env"
            log_info "Immich secrets injected"
          else
            log_warn "Could not read immich-db password from 1Password"
          fi
        fi

        # Paperless secret key
        if [ -f "$CONFIG_DIR/paperless/.env.template" ]; then
          PAPERLESS_KEY=$(op read "op://Private/paperless-secret/notesPlain" 2>/dev/null || echo "")
          if [ -n "$PAPERLESS_KEY" ]; then
            sed "s/__PAPERLESS_SECRET_KEY__/$PAPERLESS_KEY/" \
              "$CONFIG_DIR/paperless/.env.template" > "$CONFIG_DIR/paperless/.env"
            log_info "Paperless secrets injected"
          else
            log_warn "Could not read paperless-secret from 1Password"
          fi
        fi

        log_info "Secret injection complete"
      }

      # Clean up sensitive files
      cleanup_secrets() {
        log_info "Cleaning up sensitive files..."
        rm -f "$CONFIG_DIR/borgmatic/ssh/id_rsa"
        rm -f "$CONFIG_DIR/immich/.env"
        rm -f "$CONFIG_DIR/paperless/.env"
        log_info "Sensitive files removed"
      }

      start_service() {
        local service=$1
        if [ -f "$CONFIG_DIR/$service/docker-compose.yml" ]; then
          log_info "Starting $service..."
          docker compose -f "$CONFIG_DIR/$service/docker-compose.yml" up -d
        else
          log_error "No docker-compose.yml found for $service"
        fi
      }

      stop_service() {
        local service=$1
        if [ -f "$CONFIG_DIR/$service/docker-compose.yml" ]; then
          log_info "Stopping $service..."
          docker compose -f "$CONFIG_DIR/$service/docker-compose.yml" down
        fi
      }

      start_all() {
        inject_secrets
        log_info "Starting all media services..."
        for service in $SERVICES; do
          start_service "$service"
        done
        log_info "All services started!"
      }

      stop_all() {
        log_info "Stopping all media services..."
        for service in $SERVICES; do
          stop_service "$service"
        done
        cleanup_secrets
        log_info "All services stopped!"
      }

      status() {
        echo ""
        echo "=== Media Server Status ==="
        echo ""
        docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "(NAME|immich|jellyfin|paperless|borgmatic)" || echo "No media services running"
        echo ""
        echo "=== Service URLs ==="
        echo "  Immich:    http://localhost:2283"
        echo "  Jellyfin:  http://localhost:8096"
        echo "  Paperless: http://localhost:8000"
        echo ""
      }

      logs() {
        local service=$1
        if [ -z "$service" ]; then
          log_error "Usage: media-server logs <service>"
          echo "Available services: $SERVICES"
          exit 1
        fi
        if [ -f "$CONFIG_DIR/$service/docker-compose.yml" ]; then
          docker compose -f "$CONFIG_DIR/$service/docker-compose.yml" logs -f
        else
          log_error "Unknown service: $service"
        fi
      }

      case "$1" in
        start)
          if [ -n "$2" ]; then
            inject_secrets
            start_service "$2"
          else
            start_all
          fi
          ;;
        stop)
          if [ -n "$2" ]; then
            stop_service "$2"
          else
            stop_all
          fi
          ;;
        restart)
          if [ -n "$2" ]; then
            stop_service "$2"
            inject_secrets
            start_service "$2"
          else
            stop_all
            start_all
          fi
          ;;
        status)
          status
          ;;
        logs)
          logs "$2"
          ;;
        inject-secrets)
          inject_secrets
          ;;
        *)
          echo "Media Server Management"
          echo ""
          echo "Usage: media-server <command> [service]"
          echo ""
          echo "Commands:"
          echo "  start [service]    Start all services or a specific service"
          echo "  stop [service]     Stop all services or a specific service"
          echo "  restart [service]  Restart all services or a specific service"
          echo "  status             Show status of all services"
          echo "  logs <service>     Follow logs for a specific service"
          echo "  inject-secrets     Inject secrets from 1Password"
          echo ""
          echo "Services: $SERVICES"
          ;;
      esac
    '')

    # Backup management script
    (writeShellScriptBin "backup" ''
      #!/bin/bash
      set -e

      CONFIG_DIR="${configDir}/borgmatic"

      # Colors
      RED='\033[0;31m'
      GREEN='\033[0;32m'
      YELLOW='\033[1;33m'
      NC='\033[0m'

      log_info() { echo -e "''${GREEN}[INFO]''${NC} $1"; }
      log_warn() { echo -e "''${YELLOW}[WARN]''${NC} $1"; }
      log_error() { echo -e "''${RED}[ERROR]''${NC} $1"; }

      # Get passphrase from 1Password
      get_passphrase() {
        if ! command -v op &> /dev/null; then
          log_error "1Password CLI not found"
          exit 1
        fi
        op read "op://Private/Hetzner Borg Backup Keys/Passphrase" 2>/dev/null
      }

      run_backup() {
        local service=$1
        local passphrase=$(get_passphrase)

        if [ -z "$passphrase" ]; then
          log_error "Could not get passphrase from 1Password"
          exit 1
        fi

        log_info "Running backup for $service..."
        docker exec -e BORG_PASSPHRASE="$passphrase" borgmatic \
          borgmatic --config "/etc/borgmatic/config.d/$service.yaml" --verbosity 1 --stats
        log_info "Backup complete for $service"
      }

      list_archives() {
        local service=$1
        local passphrase=$(get_passphrase)

        case "$service" in
          immich) repo="ssh://REDACTED-USER-sub1@REDACTED-STORAGEBOX:23/./borg-immich" ;;
          jellyfin) repo="ssh://REDACTED-USER-sub2@REDACTED-STORAGEBOX:23/./borg-jellyfin" ;;
          paperless) repo="ssh://REDACTED-USER-sub3@REDACTED-STORAGEBOX:23/./borg-paperless" ;;
          *)
            log_error "Unknown service: $service"
            exit 1
            ;;
        esac

        log_info "Listing archives for $service..."
        docker exec -e BORG_PASSPHRASE="$passphrase" borgmatic borg list "$repo"
      }

      case "$1" in
        immich|jellyfin|paperless)
          run_backup "$1"
          ;;
        all)
          for service in immich jellyfin paperless; do
            run_backup "$service"
          done
          ;;
        list)
          if [ -z "$2" ]; then
            log_error "Usage: backup list <service>"
            exit 1
          fi
          list_archives "$2"
          ;;
        status)
          log_info "Checking backup container status..."
          docker ps --filter "name=borgmatic" --format "table {{.Names}}\t{{.Status}}"
          ;;
        *)
          echo "Backup Management"
          echo ""
          echo "Usage: backup <command> [service]"
          echo ""
          echo "Commands:"
          echo "  immich      Run backup for Immich"
          echo "  jellyfin    Run backup for Jellyfin"
          echo "  paperless   Run backup for Paperless"
          echo "  all         Run backup for all services"
          echo "  list <svc>  List archives for a service"
          echo "  status      Show borgmatic container status"
          ;;
      esac
    '')
  ];
}
