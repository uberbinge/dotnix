# darwin/mini/scripts.nix
# Helper scripts for Mac Mini media server management
{ config, pkgs, lib, ... }:

let
  cfg = config.services.mediaServer;
  miniHealth = pkgs.writeShellApplication {
    name = "mini-health";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.curl
      pkgs.dnsutils
      pkgs.docker
      pkgs.gawk
      pkgs.gnugrep
      pkgs.gnused
      pkgs.jq
      pkgs.tailscale
    ];
    text = ''
      set +e

      CONFIG_DIR="${cfg.configDir}"
      BACKUP_LOG_DIR="$CONFIG_DIR/borgmatic/logs"
      MEDIA_VOLUME="${cfg.mediaVolume}"

      IMMICH_DOMAIN="${cfg.domains.immich}"
      JELLYFIN_DOMAIN="${cfg.domains.jellyfin}"
      PAPERLESS_DOMAIN="${cfg.domains.paperless}"
      HOME_DOMAIN="${cfg.domains.homeAssistant}"

      OK=0
      WARN=0
      FAIL=0

      red='\033[0;31m'
      green='\033[0;32m'
      yellow='\033[1;33m'
      blue='\033[0;34m'
      nc='\033[0m'

      section() {
        printf '\n%b%s%b\n' "$blue" "$1" "$nc"
      }

      pass() {
        OK=$((OK + 1))
        printf '  %bOK%b    %s\n' "$green" "$nc" "$1"
      }

      warn() {
        WARN=$((WARN + 1))
        printf '  %bWARN%b  %s\n' "$yellow" "$nc" "$1"
      }

      fail() {
        FAIL=$((FAIL + 1))
        printf '  %bFAIL%b  %s\n' "$red" "$nc" "$1"
      }

      have() {
        command -v "$1" >/dev/null 2>&1
      }

      http_code() {
        curl -k -sS -o /dev/null -w '%{http_code}' --max-time 8 "$1" 2>/dev/null
      }

      local_https_code() {
        domain="$1"
        path="''${2:-/}"
        curl -k -sS -o /dev/null -w '%{http_code}' --max-time 8 \
          --resolve "$domain:443:127.0.0.1" "https://$domain$path" 2>/dev/null
      }

      stat_mtime() {
        /usr/bin/stat -f %m "$1" 2>/dev/null || stat -c %Y "$1" 2>/dev/null
      }

      check_tailscale() {
        section "Tailscale"

        if ! have tailscale; then
          fail "tailscale CLI is not available"
          return
        fi

        json="$(tailscale status --json 2>/dev/null)"
        if [ -z "$json" ]; then
          fail "tailscale status did not return JSON"
          return
        fi

        backend="$(printf '%s' "$json" | jq -r '.BackendState // "unknown"')"
        ip="$(printf '%s' "$json" | jq -r '.TailscaleIPs[0] // ""')"
        dns="$(printf '%s' "$json" | jq -r '.Self.DNSName // ""')"

        if [ "$backend" = "Running" ]; then
          pass "backend running as $dns ($ip)"
        else
          active="$(printf '%s' "$json" | jq -r '.Self.Active // false')"
          fail "backend state is $backend, active=$active; service hostnames may not resolve or route"
        fi

        routes="$(printf '%s' "$json" | jq -r '.Self.AllowedIPs[]? // empty' | grep -E '^(0\.0\.0\.0/0|::/0)$' | paste -sd ' ' -)"
        if [ -n "$routes" ]; then
          pass "exit-node routes advertised: $routes"
        else
          warn "exit-node routes are not currently advertised"
        fi
      }

      check_launchd() {
        label="$1"
        name="$2"

        output="$(launchctl print "gui/$(id -u)/$label" 2>/dev/null)"
        if [ -z "$output" ]; then
          fail "$name LaunchAgent is not loaded ($label)"
          return
        fi

        state="$(printf '%s\n' "$output" | sed -n 's/^[[:space:]]*state = //p' | head -n 1)"
        pid="$(printf '%s\n' "$output" | sed -n 's/^[[:space:]]*pid = //p' | head -n 1)"
        last_exit="$(printf '%s\n' "$output" | sed -n 's/^[[:space:]]*last exit code = //p' | head -n 1)"

        if [ "$state" = "running" ]; then
          pass "$name LaunchAgent running''${pid:+ (pid $pid)}"
        else
          warn "$name LaunchAgent state=$state''${last_exit:+, last exit=$last_exit}"
        fi
      }

      check_docker_container() {
        name="$1"
        required="$2"

        inspect="$(docker inspect -f '{{.State.Running}} {{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$name" 2>/dev/null)"
        if [ -z "$inspect" ]; then
          if [ "$required" = "required" ]; then
            fail "$name container is missing"
          else
            warn "$name container is missing"
          fi
          return
        fi

        running="$(printf '%s' "$inspect" | awk '{print $1}')"
        health="$(printf '%s' "$inspect" | awk '{print $2}')"

        if [ "$running" != "true" ]; then
          fail "$name container is not running"
        elif [ "$health" = "healthy" ] || [ "$health" = "none" ]; then
          pass "$name running''${health:+, health=$health}"
        else
          fail "$name running, health=$health"
        fi
      }

      check_http() {
        name="$1"
        url="$2"
        expected_regex="$3"
        severity="''${4:-fail}"

        code="$(http_code "$url")"
        if printf '%s' "$code" | grep -Eq "$expected_regex"; then
          pass "$name $url -> HTTP $code"
        elif [ "$severity" = "warn" ]; then
          warn "$name $url -> HTTP ''${code:-000}"
        else
          fail "$name $url -> HTTP ''${code:-000}"
        fi
      }

      check_caddy_route() {
        name="$1"
        domain="$2"
        expected_regex="$3"
        severity="''${4:-fail}"

        code="$(local_https_code "$domain" /)"
        if printf '%s' "$code" | grep -Eq "$expected_regex"; then
          pass "$name via Caddy https://$domain/ -> HTTP $code"
        elif [ "$severity" = "warn" ]; then
          warn "$name via Caddy https://$domain/ -> HTTP ''${code:-000}"
        else
          fail "$name via Caddy https://$domain/ -> HTTP ''${code:-000}"
        fi
      }

      check_dns_name() {
        domain="$1"
        cname="$(dig +short "$domain" 2>/dev/null | paste -sd ' ' -)"
        if [ -n "$cname" ]; then
          pass "$domain resolves to $cname"
        else
          warn "$domain does not resolve from this host; this is expected when Tailscale DNS is stopped"
        fi
      }

      check_disk() {
        path="$1"
        label="$2"

        if [ ! -e "$path" ]; then
          fail "$label path is missing: $path"
          return
        fi

        usage="$(df -Pk "$path" 2>/dev/null | awk 'NR==2 {gsub(/%/, "", $5); print $5}')"
        avail_kb="$(df -Pk "$path" 2>/dev/null | awk 'NR==2 {print $4}')"
        if [ -z "$usage" ]; then
          warn "could not read disk usage for $label ($path)"
        elif [ "$usage" -ge 95 ]; then
          fail "$label disk usage is $usage% ($(awk "BEGIN {printf \"%.1f\", $avail_kb / 1024 / 1024}") GiB free)"
        elif [ "$usage" -ge 90 ]; then
          warn "$label disk usage is $usage% ($(awk "BEGIN {printf \"%.1f\", $avail_kb / 1024 / 1024}") GiB free)"
        else
          pass "$label disk usage is $usage% ($(awk "BEGIN {printf \"%.1f\", $avail_kb / 1024 / 1024}") GiB free)"
        fi
      }

      check_backup_log() {
        service="$1"
        log="$BACKUP_LOG_DIR/$service-cron.log"
        status_file="$BACKUP_LOG_DIR/status/$service.status"

        if [ -f "$status_file" ]; then
          status="$(grep '^status=' "$status_file" | tail -n 1 | cut -d= -f2-)"
          source="$(grep '^source=' "$status_file" | tail -n 1 | cut -d= -f2-)"
          finished_epoch="$(grep '^finished_epoch=' "$status_file" | tail -n 1 | cut -d= -f2-)"
          exit_code="$(grep '^exit_code=' "$status_file" | tail -n 1 | cut -d= -f2-)"
          now="$(date +%s)"
          age_hours=""

          if [ -n "$finished_epoch" ]; then
            age_hours="$(( (now - finished_epoch) / 3600 ))"
          fi

          if [ "$status" = "success" ]; then
            if [ -n "$age_hours" ] && [ "$age_hours" -gt 36 ]; then
              warn "$service last $source backup status is successful but old: ''${age_hours}h"
            else
              pass "$service last $source backup status is success''${age_hours:+ ($age_hours h ago)}"
            fi
          elif [ "$status" = "failed" ]; then
            fail "$service last $source backup failed''${exit_code:+ (exit $exit_code)}"
          else
            warn "$service backup status file has unknown status: ''${status:-empty}"
          fi
          return
        fi

        if [ ! -f "$log" ]; then
          warn "$service backup log is missing: $log"
          return
        fi

        now="$(date +%s)"
        mtime="$(stat_mtime "$log")"
        age_hours=""

        recent="$(tail -n 120 "$log" 2>/dev/null)"
        last_start="$(printf '%s\n' "$recent" | grep "Time (start):" | tail -n 1 | sed 's/^.*Time (start):[[:space:]]*//')"
        start_epoch=""
        if [ -n "$last_start" ]; then
          start_epoch="$(date -d "$last_start" +%s 2>/dev/null || true)"
        fi
        if [ -n "$start_epoch" ]; then
          age_hours="$(( (now - start_epoch) / 3600 ))"
        elif [ -n "$mtime" ]; then
          age_hours="$(( (now - mtime) / 3600 ))"
        fi

        if printf '%s\n' "$recent" | grep -q "Successfully ran configuration file"; then
          if [ -n "$age_hours" ] && [ "$age_hours" -gt 36 ]; then
            warn "$service last backup log is successful but old: ''${age_hours}h"
          else
            pass "$service last backup log reports success''${age_hours:+ ($age_hours h ago)}"
          fi
        elif printf '%s\n' "$recent" | grep -q "An error occurred"; then
          fail "$service last backup log reports an error"
        else
          warn "$service backup log has no recent summary"
        fi
      }

      printf 'Mini server health check - %s\n' "$(date '+%Y-%m-%d %H:%M:%S %Z')"

      check_tailscale

      section "LaunchAgents"
      check_launchd com.caddyserver.caddy Caddy
      check_launchd com.jellyfin.server Jellyfin

      section "Docker Containers"
      if docker info >/dev/null 2>&1; then
        check_docker_container immich_server required
        check_docker_container immich_postgres required
        check_docker_container immich_redis required
        check_docker_container immich_machine_learning required
        check_docker_container paperless_webserver required
        check_docker_container paperless_db required
        check_docker_container paperless_broker required
        check_docker_container home-assistant optional
        check_docker_container borgmatic required
      else
        fail "Docker is not reachable"
      fi

      section "Local Backends"
      check_http Immich http://127.0.0.1:2283/ '^(200|302)$'
      check_http Jellyfin http://127.0.0.1:8096/System/Info/Public '^200$'
      check_http Paperless http://127.0.0.1:8000/ '^(200|302|403)$'
      check_http "Home Assistant" http://127.0.0.1:8123/ '^(200|302|400|405)$' warn
      check_http "Health Export" http://127.0.0.1:9876/health '^200$' warn

      section "Caddy Routes"
      check_caddy_route Immich "$IMMICH_DOMAIN" '^(200|302)$'
      check_caddy_route Jellyfin "$JELLYFIN_DOMAIN" '^(200|302)$'
      check_caddy_route Paperless "$PAPERLESS_DOMAIN" '^(200|302|403)$'
      check_caddy_route "Home Assistant" "$HOME_DOMAIN" '^(200|302)$' warn

      section "DNS"
      check_dns_name "$IMMICH_DOMAIN"
      check_dns_name "$JELLYFIN_DOMAIN"
      check_dns_name "$PAPERLESS_DOMAIN"
      check_dns_name "$HOME_DOMAIN"

      section "Disk"
      check_disk / "System"
      check_disk "$MEDIA_VOLUME" "Media volume"

      section "Backups"
      check_backup_log immich
      check_backup_log jellyfin
      check_backup_log paperless

      printf '\nSummary: %b%d OK%b, %b%d WARN%b, %b%d FAIL%b\n' \
        "$green" "$OK" "$nc" "$yellow" "$WARN" "$nc" "$red" "$FAIL" "$nc"

      if [ "$FAIL" -gt 0 ]; then
        exit 2
      fi
      if [ "$WARN" -gt 0 ]; then
        exit 1
      fi
    '';
  };
in
{
  home.packages = [
    miniHealth

    # Unified media server management script
    (pkgs.writeShellApplication {
      name = "media-server";
      runtimeInputs = [ pkgs.docker ];
      text = ''
        SERVICES="immich jellyfin paperless borgmatic ha"

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
          if command -v mini-health >/dev/null 2>&1; then
            mini-health
          else
            echo ""
            echo "=== Media Server Status ==="
            echo ""
            docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "(NAME|immich|jellyfin|paperless|borgmatic|home-assistant)" || echo "No media services running"
            echo ""
            echo "=== Service URLs ==="
            echo "  Immich:         http://localhost:2283"
            echo "  Jellyfin:       http://localhost:8096"
            echo "  Paperless:      http://localhost:8000"
            echo "  Home Assistant: http://localhost:8123"
            echo ""
          fi
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

        case "''${1:-}" in
          start)
            if [ -n "''${2:-}" ]; then
              start_service "$2"
            else
              start_all
            fi
            ;;
          stop)
            if [ -n "''${2:-}" ]; then
              stop_service "$2"
            else
              stop_all
            fi
            ;;
          restart)
            if [ -n "''${2:-}" ]; then
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
            logs "''${2:-}"
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
      '';
    })

    # Simple backup wrapper using borgmatic commands
    (pkgs.writeShellApplication {
      name = "backup";
      runtimeInputs = [ ];
      text = ''
        # Colors
        GREEN='\033[0;32m'
        NC='\033[0m'

        log_info() { echo -e "''${GREEN}[INFO]''${NC} $1"; }

        case "''${1:-}" in
          immich|jellyfin|paperless)
            log_info "Running $1 backup using borgmatic-backup..."
            borgmatic-backup "$1"
            ;;
          all)
            log_info "Running all backups using borgmatic-backup..."
            borgmatic-backup all
            ;;
          list)
            if [ -z "''${2:-}" ]; then
              echo "Usage: backup list <service>"
              exit 1
            fi
            log_info "Listing $2 archives using borgmatic-list..."
            borgmatic-list "$2"
            ;;
          check)
            if [ -z "''${2:-}" ]; then
              echo "Usage: backup check <service|all>"
              exit 1
            fi
            log_info "Checking $2 repository using borgmatic-check..."
            borgmatic-check "$2"
            ;;
          info)
            if [ -z "''${2:-}" ]; then
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
      '';
    })
  ];
}
