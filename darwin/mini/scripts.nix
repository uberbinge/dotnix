# darwin/mini/scripts.nix
# Helper scripts for Mac Mini media server management
{ config, pkgs, lib, ... }:

let
  miniLib = import ./lib.nix { inherit config pkgs lib; };
  inherit (miniLib) configDir;
in
{
  home.packages = with pkgs; [
    # Unified media server management script
    # Uses individual service commands (immich-start, jellyfin-start, etc.)
    (writeShellScriptBin "media-server" ''
      #!/bin/bash
      set -e

      SERVICES="immich jellyfin paperless borgmatic"

      # Colors for output
      RED='\033[0;31m'
      GREEN='\033[0;32m'
      YELLOW='\033[1;33m'
      NC='\033[0m' # No Color

      log_info() { echo -e "''${GREEN}[INFO]''${NC} $1"; }
      log_warn() { echo -e "''${YELLOW}[WARN]''${NC} $1"; }
      log_error() { echo -e "''${RED}[ERROR]''${NC} $1"; }

      start_service() {
        local service=$1
        if command -v "$service-start" &> /dev/null; then
          log_info "Starting $service..."
          "$service-start"
        else
          log_error "Command $service-start not found"
          return 1
        fi
      }

      stop_service() {
        local service=$1
        if command -v "$service-stop" &> /dev/null; then
          log_info "Stopping $service..."
          "$service-stop"
        else
          log_error "Command $service-stop not found"
          return 1
        fi
      }

      start_all() {
        log_info "Starting all media services..."
        for service in $SERVICES; do
          start_service "$service" || log_warn "Failed to start $service"
        done
        log_info "All services started!"
      }

      stop_all() {
        log_info "Stopping all media services..."
        for service in $SERVICES; do
          stop_service "$service" || log_warn "Failed to stop $service"
        done
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
        if command -v "$service-logs" &> /dev/null; then
          "$service-logs"
        else
          log_error "Command $service-logs not found"
          exit 1
        fi
      }

      case "$1" in
        start)
          if [ -n "$2" ]; then
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
          echo ""
          echo "Services: $SERVICES"
          echo ""
          echo "Individual service commands are also available:"
          echo "  <service>-start, <service>-stop, <service>-restart,"
          echo "  <service>-status, <service>-logs, <service>-update"
          ;;
      esac
    '')

    # Simple backup wrapper using borgmatic commands
    (writeShellScriptBin "backup" ''
      #!/bin/bash
      set -e

      # Colors
      GREEN='\033[0;32m'
      NC='\033[0m'

      log_info() { echo -e "''${GREEN}[INFO]''${NC} $1"; }

      case "$1" in
        immich|jellyfin|paperless)
          log_info "Running $1 backup using borgmatic-backup..."
          borgmatic-backup "$1"
          ;;
        all)
          log_info "Running all backups using borgmatic-backup..."
          borgmatic-backup all
          ;;
        list)
          if [ -z "$2" ]; then
            echo "Usage: backup list <service>"
            exit 1
          fi
          log_info "Listing $2 archives using borgmatic-list..."
          borgmatic-list "$2"
          ;;
        check)
          if [ -z "$2" ]; then
            echo "Usage: backup check <service|all>"
            exit 1
          fi
          log_info "Checking $2 repository using borgmatic-check..."
          borgmatic-check "$2"
          ;;
        info)
          if [ -z "$2" ]; then
            echo "Usage: backup info <service>"
            exit 1
          fi
          log_info "Getting info for $2 using borgmatic-info..."
          borgmatic-info "$2"
          ;;
        status)
          log_info "Checking backup container status..."
          borgmatic-status
          ;;
        *)
          echo "Backup Management (wrapper for borgmatic commands)"
          echo ""
          echo "Usage: backup <command> [service]"
          echo ""
          echo "Commands:"
          echo "  immich        Run backup for Immich"
          echo "  jellyfin      Run backup for Jellyfin"
          echo "  paperless     Run backup for Paperless"
          echo "  all           Run backup for all services"
          echo "  list <svc>    List archives for a service"
          echo "  check <svc>   Check repository integrity"
          echo "  info <svc>    Show repository info"
          echo "  status        Show borgmatic container status"
          echo ""
          echo "Or use borgmatic-* commands directly:"
          echo "  borgmatic-backup, borgmatic-list, borgmatic-check,"
          echo "  borgmatic-info, borgmatic-status, borgmatic-logs"
          ;;
      esac
    '')
  ];
}
