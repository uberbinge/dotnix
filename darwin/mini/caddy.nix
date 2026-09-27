# darwin/mini/caddy.nix
# Caddy reverse proxy with Cloudflare DNS for automatic HTTPS
{ config, pkgs, lib, username, ... }:

let
  # Caddy with Cloudflare DNS plugin for DNS-01 ACME challenge
  caddyWithCloudflare = pkgs.caddy.withPlugins {
    plugins = [ "github.com/caddy-dns/cloudflare@v0.2.2" ];
    hash = "sha256-7g8zDx5RhbptXFyEPtexxkHX8hw/gF001bZ7wX4Mjhs=";
  };

  caddyConfigDir = "${config.home.homeDirectory}/.config/caddy";
  caddyDataDir = "${config.home.homeDirectory}/.local/share/caddy";
  caddyLogDir = "${config.home.homeDirectory}/.local/share/caddy/logs";
  domains = config.services.mediaServer.domains;

  # Wrapper script that loads Cloudflare token from 1Password
  caddyWrapper = pkgs.writeShellApplication {
    name = "caddy-run";
    runtimeInputs = [ pkgs._1password-cli caddyWithCloudflare ];
    text = ''
      # Load Cloudflare API token from 1Password
      CLOUDFLARE_API_TOKEN="$(op read "op://Automation/cloudflare-api-token/credential" 2>/dev/null || echo "")"
      export CLOUDFLARE_API_TOKEN

      if [ -z "$CLOUDFLARE_API_TOKEN" ]; then
        echo "ERROR: Failed to load Cloudflare API token from 1Password" >&2
        echo "Make sure 1Password CLI is authenticated and the item exists" >&2
        exit 1
      fi

      exec caddy "$@"
    '';
  };

  # Graceful reload through the admin API (localhost:2019): live sites keep serving,
  # and an invalid Caddyfile is rejected before it replaces the running config.
  caddyReload = pkgs.writeShellApplication {
    name = "caddy-reload";
    runtimeInputs = [ pkgs._1password-cli caddyWithCloudflare ];
    text = ''
      CONFIG="${caddyConfigDir}/Caddyfile"
      CLOUDFLARE_API_TOKEN="$(op read "op://Automation/cloudflare-api-token/credential" 2>/dev/null || echo "")"
      export CLOUDFLARE_API_TOKEN
      if [ -z "$CLOUDFLARE_API_TOKEN" ]; then
        echo "caddy-reload: could not read Cloudflare token from 1Password; run caddy-reload manually" >&2
        exit 1
      fi
      caddy validate --config "$CONFIG" --adapter caddyfile
      caddy reload --config "$CONFIG" --adapter caddyfile
      echo "caddy-reload: config reloaded"
    '';
  };
in
{
  home.packages = [
    caddyWithCloudflare
    caddyWrapper
    caddyReload
  ];

  # Create required directories
  home.file = {
    "${caddyConfigDir}/.keep".text = "";
    "${caddyDataDir}/.keep".text = "";
    "${caddyLogDir}/.keep".text = "";
  };

  # Caddyfile configuration
  home.file."${caddyConfigDir}/Caddyfile".text = ''
    # Global options
    {
      # Use Cloudflare DNS for ACME challenges
      acme_dns cloudflare {env.CLOUDFLARE_API_TOKEN}
    }

    # Common TLS configuration using Cloudflare DNS
    (cloudflare) {
      tls {
        dns cloudflare {env.CLOUDFLARE_API_TOKEN}
      }
    }

    # Immich - Photo management
    ${domains.immich} {
      reverse_proxy http://localhost:2283
      import cloudflare
    }

    # Jellyfin - Media server
    ${domains.jellyfin} {
      import cloudflare

      reverse_proxy http://localhost:8096 {
        header_up X-Real-IP {remote_host}
        header_up X-Forwarded-For {remote_host}
        header_up X-Forwarded-Proto {scheme}
        header_up X-Forwarded-Host {host}
        transport http {
          read_buffer 8192
        }
      }
    }

    # Paperless - Document management
    ${domains.paperless} {
      reverse_proxy http://localhost:8000
      import cloudflare
    }

    # health-export - HealthKit sync + query API (iPhone app, hk-cli)
    ${domains.health} {
      reverse_proxy http://127.0.0.1:9876
      import cloudflare
    }

    # tt-coach - coaching video search (SPA + API + video streaming)
    ${domains.ttCoach} {
      reverse_proxy http://127.0.0.1:5001
      import cloudflare
    }

    # Home Assistant
    ${domains.homeAssistant} {
      reverse_proxy http://localhost:8123
      import cloudflare
    }
  '';

  # Caddy only reads its config at startup; a rebuild swaps the Caddyfile symlink but
  # the long-running process keeps the old config. Reload when the file actually changed.
  # Never fails the rebuild: a reload problem is reported, the old config keeps serving.
  home.activation.caddyReload = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    STAMP="${caddyDataDir}/.last-reloaded-caddyfile"
    CURRENT="$(readlink -f "${caddyConfigDir}/Caddyfile" 2>/dev/null || echo "")"
    if [ -n "$CURRENT" ] && [ "$(cat "$STAMP" 2>/dev/null || echo "")" != "$CURRENT" ]; then
      if /usr/bin/curl -sf --max-time 2 http://localhost:2019/config/ >/dev/null 2>&1; then
        if $DRY_RUN_CMD ${caddyReload}/bin/caddy-reload; then
          $DRY_RUN_CMD sh -c 'echo "$1" > "$2"' _ "$CURRENT" "$STAMP"
        else
          echo "WARNING: Caddy reload failed; still serving the previous config. Run: caddy-reload"
        fi
      else
        echo "Caddy admin API not up; launchd start will load the new Caddyfile"
      fi
    fi
  '';

  # launchd service for Caddy
  launchd.agents.caddy = {
    enable = true;
    config = {
      Label = "com.caddyserver.caddy";
      ProgramArguments = [
        "${caddyWrapper}/bin/caddy-run"
        "run"
        "--config"
        "${caddyConfigDir}/Caddyfile"
      ];
      RunAtLoad = true;
      KeepAlive = true;
      WorkingDirectory = caddyDataDir;
      EnvironmentVariables = {
        HOME = config.home.homeDirectory;
        XDG_DATA_HOME = "${config.home.homeDirectory}/.local/share";
        XDG_CONFIG_HOME = "${config.home.homeDirectory}/.config";
      };
      StandardOutPath = "${caddyLogDir}/caddy.log";
      StandardErrorPath = "${caddyLogDir}/caddy.log";
    };
  };
}
