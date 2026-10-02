# Mac Mini (media server)

Guidance for the `mini` machine (`.#mini`, user `waqas`). Loaded when working under `darwin/mini/`.

## Mac Mini Service Commands

Each service has consistent management commands:

| Service | Start | Stop | Logs | Status | Update |
|---------|-------|------|------|--------|--------|
| Jellyfin | `jellyfin-start` | `jellyfin-stop` | `jellyfin-logs` | `jellyfin-status` | `jellyfin-update` |
| Immich | `immich-start` | `immich-stop` | `immich-logs` | `immich-status` | `immich-update` |
| Paperless | `paperless-start` | `paperless-stop` | `paperless-logs` | `paperless-status` | `paperless-update` |
| Home Assistant | `ha-start` | `ha-stop` | `ha-logs` | `ha-status` | `ha-update` |
| Borgmatic | `borgmatic-start` | `borgmatic-stop` | `borgmatic-logs` | `borgmatic-status` | - |

### Borgmatic Backup Commands
```bash
borgmatic-backup <service>   # Run backup for immich/jellyfin/paperless
borgmatic-list <service>     # List archives
borgmatic-info <service>     # Show repo info
borgmatic-init <service>     # Initialize new repo
```

## Service URLs (Mac Mini)
- **Jellyfin**: http://localhost:8096
- **Immich**: http://localhost:2283
- **Paperless**: http://localhost:8000
- **Home Assistant**: http://localhost:8123

## Adding a New Service (Mini)

1. Create `darwin/mini/services/<service>.nix`
2. Add to imports in `darwin/mini/default.nix`
3. Create 1Password items for any secrets
4. Rebuild: `sudo darwin-rebuild switch --flake ~/dev/dotnix#mini`
5. Start: `<service>-start`

## Adding a New Backup (Borgmatic)

1. Create Hetzner sub-account (e.g., `sub4`)
2. Add SSH public key to sub-account
3. Add known_hosts entry in `borgmatic.nix`
4. Add backup config using `mkBorgmaticConfig`
5. Add volume mount in docker-compose section
6. Add cron schedule
7. Rebuild and run `borgmatic-init <service>`
