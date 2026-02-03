# darwin/mini/caddy.nix
# Caddy reverse proxy with Cloudflare DNS for automatic HTTPS
{ config, pkgs, lib, username, ... }:

let
  # Caddy with Cloudflare DNS plugin for DNS-01 ACME challenge
  caddyWithCloudflare = pkgs.caddy.withPlugins {
    plugins = [ "github.com/caddy-dns/cloudflare@v0.2.2" ];
    hash = "sha256-dnhEjopeA0UiI+XVYHYpsjcEI6Y1Hacbi28hVKYQURg=";
  };

  caddyConfigDir = "${config.home.homeDirectory}/.config/caddy";
  caddyDataDir = "${config.home.homeDirectory}/.local/share/caddy";
  caddyLogDir = "${config.home.homeDirectory}/.local/share/caddy/logs";

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
in
{
  home.packages = [
    caddyWithCloudflare
    caddyWrapper
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
    immich.ti.waqas.dev {
      reverse_proxy http://localhost:2283
      import cloudflare
    }

    # Jellyfin - Media server
    jelly.ti.waqas.dev {
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
    paperless.ti.waqas.dev {
      reverse_proxy http://localhost:8000
      import cloudflare
    }

    # Home Assistant
    home.ti.waqas.dev {
      reverse_proxy http://localhost:8123
      import cloudflare
    }
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
