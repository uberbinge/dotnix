# Mac Mini Media Server Setup

This directory contains the Nix configuration for the Mac Mini media server, managing several Docker-based services.

## Architecture

The configuration uses a **shared library pattern** (`lib.nix`) to eliminate code duplication and ensure consistency across services.

### Structure

```
darwin/mini/
├── lib.nix              # Shared functions and values
├── default.nix          # Main entry point
├── homebrew.nix         # Mini-specific brew packages (currently empty)
├── services/            # Individual service configurations
│   ├── immich.nix       # Photo management
│   ├── jellyfin.nix     # Media server
│   └── paperless.nix    # Document management
├── borgmatic.nix        # Backup configuration
├── caddy.nix            # Reverse proxy with HTTPS
└── scripts.nix          # Management scripts
```

## Services

### Immich (Photo Management)
- **Port**: 2283
- **Domain**: immich.ti.waqas.dev
- **Storage**: `/Volumes/4tb/immich/`
- **Secrets**: Database password from 1Password (`immich-db`)
- **Backups**: Daily at 2 AM to Hetzner sub1

### Jellyfin (Media Server)
- **Port**: 8096
- **Domain**: jelly.ti.waqas.dev
- **Storage**: `/Volumes/4tb/jellyfin/`
- **Secrets**: None (no external auth)
- **Backups**: Daily at 4 AM to Hetzner sub2

### Paperless-ngx (Document Management)
- **Port**: 8000
- **Domain**: paperless.ti.waqas.dev
- **Storage**: `/Volumes/4tb/paperless/`
- **Secrets**: Database password and secret key from 1Password
- **Backups**: Daily at 5 AM to Hetzner sub3 (12-month retention)

### Borgmatic (Backups)
- **Destination**: Hetzner Storage Box (3 sub-accounts)
- **Schedule**: Sequential daily backups (2 AM, 4 AM, 5 AM)
- **Encryption**: Borg with passphrase from 1Password
- **Retention**: 1 day, 4 weeks, 6-12 months

### Caddy (Reverse Proxy)
- **Features**: Automatic HTTPS with Cloudflare DNS-01
- **Domains**: *.ti.waqas.dev
- **Token**: Cloudflare API token from 1Password

## Management Commands

### Individual Services

Each service has a full set of commands:

```bash
# Start/stop/restart services
immich-start / immich-stop / immich-restart
jellyfin-start / jellyfin-stop / jellyfin-restart
paperless-start / paperless-stop / paperless-restart
borgmatic-start / borgmatic-stop

# View logs and status
immich-logs / immich-status
jellyfin-logs / jellyfin-status
paperless-logs / paperless-status
borgmatic-logs / borgmatic-status

# Update to latest images
immich-update
jellyfin-update
paperless-update
```

### Unified Management

```bash
# Manage all services at once
media-server start          # Start all services
media-server stop           # Stop all services
media-server restart        # Restart all services
media-server status         # Show Docker status
media-server logs <service> # Follow logs for a service

# Or manage individual services
media-server start immich
media-server stop jellyfin
```

### Backup Management

```bash
# Run backups manually
backup immich      # Backup Immich
backup jellyfin    # Backup Jellyfin
backup paperless   # Backup Paperless
backup all         # Backup everything

# Inspect backups
backup list immich      # List Immich archives
backup check immich     # Verify repository integrity
backup info immich      # Show repository info
backup status           # Check borgmatic container

# Or use borgmatic commands directly
borgmatic-backup immich
borgmatic-list immich
borgmatic-check all
borgmatic-info jellyfin
```

## Adding a New Service

To add a new Docker Compose service:

1. Create `darwin/mini/services/newservice.nix`:

```nix
{ config, pkgs, lib, username, ... }:

let
  miniLib = import ../lib.nix { inherit config pkgs lib; };
  inherit (miniLib) mediaVolume mkDockerComposeScripts mkLaunchdService;
  
  configDir = "${miniLib.configDir}/newservice";

  # Optional: 1Password secrets
  # inherit (miniLib) fetch1PasswordSecret validate1PasswordSecret;
  # secretEnvSetup = ''
  #   SECRET=${fetch1PasswordSecret { item = "my-secret"; }}
  #   ${validate1PasswordSecret { secretVar = "SECRET"; item = "my-secret"; }}
  # '';

  scripts = mkDockerComposeScripts {
    serviceName = "newservice";
    inherit configDir;
    # extraEnvSetup = secretEnvSetup;  # If needed
  };
in
{
  home.packages = scripts.scripts;
  
  home.file."${configDir}/.keep".text = "";
  
  home.file."${configDir}/docker-compose.yml".text = ''
    name: newservice
    services:
      newservice:
        image: ghcr.io/org/newservice:latest
        # ... your config
  '';

  launchd.agents.newservice = mkLaunchdService {
    serviceName = "newservice";
    startScript = scripts.start;
    inherit configDir;
  };

  home.file."${config.home.homeDirectory}/.local/share/newservice/.keep".text = "";
}
```

2. Import in `default.nix`:

```nix
imports = [
  # ...
  ./services/newservice.nix
];
```

3. Add to scripts.nix SERVICES list if you want unified management

4. Optionally add a borgmatic backup configuration in `borgmatic.nix`

## Auto-Start on Boot

All services are configured with launchd to start automatically on boot:
- `RunAtLoad = true` - Start when system boots
- `KeepAlive = false` - Don't restart if stopped (Docker handles container lifecycle)

To disable auto-start for a service, rebuild with that service's launchd disabled.

## Secrets Management

All secrets are fetched from 1Password at service start time:
- Never stored in Nix store
- Generated into `.env` files in config directories
- `.env` files are gitignored

**Required 1Password Items** (Private vault):
- `immich-db` - password field
- `paperless-db` - password field  
- `paperless-secret` - notesPlain field
- `Hetzner Borg Backup Keys` - ssh-private-key and Passphrase fields
- `cloudflare-api-token` - credential field

## Configuration Changes

After modifying any `.nix` files:

```bash
# Apply changes
darwin-rebuild switch --flake ~/dev/dotnix#mini

# Or use the quick rebuild alias
hs
```

Services with `force = true` in their config files will be updated automatically. Others may need manual restart:

```bash
media-server restart <service>
```

## Troubleshooting

### Service won't start
```bash
# Check launchd logs
cat ~/.local/share/immich/launchd.log

# Check Docker logs
immich-logs
docker ps -a  # See if container is present
```

### 1Password secrets failing
```bash
# Ensure you're signed in
op signin

# Test secret access
op read "op://Private/immich-db/password"
```

### Backups failing
```bash
# Check borgmatic logs
borgmatic-logs

# Check SSH connectivity
ssh -i ~/.config/media-server/borgmatic/ssh/id_rsa -p 23 u491197-sub1@u491197-sub1.your-storagebox.de
```

### Volume not mounted
```bash
# Check if volume is mounted
ls -la /Volumes/4tb

# Mount manually if needed
# (depends on your external drive setup)
```

## Implementation Details

### Shared Library (`lib.nix`)

The shared library provides:

1. **Common Values**: mediaVolume, configDir, userId, groupId
2. **Script Generators**: `mkDockerComposeScripts` creates all 6 management scripts
3. **Service Helpers**: `mkLaunchdService` for consistent auto-start configuration
4. **Secret Helpers**: `fetch1PasswordSecret` and `validate1PasswordSecret` for DRY 1Password integration

This eliminates ~300 lines of duplicate code across the three main services.

### Why Docker?

While Nix can build containers, we use Docker Compose here because:
- These applications don't have reliable Nix packages
- Official Docker images are well-maintained
- Docker Compose is simpler for complex multi-container apps (Immich, Paperless)
- Easier to update (just pull new images)

The Nix configuration manages:
- Docker Compose files (declarative in Nix)
- Management scripts (pure Nix derivations)
- Auto-start via launchd
- Secrets fetching from 1Password

## Security Notes

- All secrets are fetched at runtime from 1Password
- SSH keys for backups are stored in 1Password, fetched on demand
- `.env` files containing secrets are never committed to git
- Borg repositories are encrypted with a passphrase from 1Password
- Caddy handles HTTPS certificates automatically via Cloudflare DNS
