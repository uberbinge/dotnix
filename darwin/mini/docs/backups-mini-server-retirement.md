# Retiring `backups-mini-server`

`backups-mini-server` is superseded by the Nix-managed borgmatic setup in
`dotnix/darwin/mini/borgmatic.nix`.

## Why Retire It

- It contains tracked backup SSH material and exported Borg keys.
- It has hardcoded legacy borgmatic config.
- It can drift from the Nix-managed service definitions.
- `borgmatic-dashboard` now reads logs from
  `~/.config/media-server/borgmatic/logs`.

## Safe Retirement Order

1. Confirm the Nix-managed borgmatic container is the active one.
2. Confirm recent backups exist for Immich, Jellyfin, and Paperless.
3. Rotate any credentials that were committed or pushed:
   - Hetzner Storage Box SSH key
   - Borg repository passphrase
   - Exported Borg keys
   - Telegram token, if it was ever committed
4. Store rotated credentials in 1Password.
5. Confirm `borgmatic-start` fetches the new credentials and backups still run.
6. Run at least one staged restore using `restore-runbook.md`.
7. Stop using `~/dev/backups-mini-server` for live operations.
8. Only after rotation and verification, remove tracked secrets from that repo or
   archive the repo.

Do not delete local secret files, Docker volumes, Borg repositories, or backup
archives as part of retirement without explicit approval.

## Startup and safety behavior

Mini services wait up to roughly 105 seconds (including termination grace periods) for Docker, then fail with an explicit manual retry command. Each 1Password read is limited to 20 seconds plus a two-second termination grace period. Unlock/authorize 1Password yourself, then rerun the service start command; activation never grants access. Activation never invokes the Caddy secret-fetching reload command: it reports `caddy-reload` when needed and leaves the previous configuration serving. That manual command makes at most two bounded attempts and records its successful reload atomically. Caddy launchd startup is one-shot (KeepAlive=false) to prevent repeated authentication prompts on failure; restart manually with `launchctl kickstart gui/$(id -u)/com.caddyserver.caddy` after prerequisites are ready. Automatic crash restarts are consequently disabled.

Immich, Paperless and Home Assistant publish their backend ports only on loopback. Caddy permits loopback and Tailscale address ranges and rejects other client addresses. Direct LAN access to those backends is intentionally removed; test tailnet access after applying on Mini. DNS names alone are not an access control.

Borgmatic is an explicit exception to the Mac interactive SSH agent policy: its container uses a dedicated backup key exported at runtime to a private host directory. Generated secret files are created privately and replaced atomically. No existing credentials are deleted by these changes. Container cron copies selected environment values as data, never shell code.

The local Immich mirror checks exact mounted paths, distinct volume UUIDs, and expected library/postgres directories before rsync --delete. Both `services.mediaServer.localBackup.sourceVolumeUUID` and `destinationVolumeUUID` must be explicitly enrolled from verified disks using `diskutil info -plist PATH`; unset values fail closed. Replacing or swapping disks requires reviewing their identities and updating these options. Run `local-backup-run --dry-run` before the first mirror; it does not create directories or logs. The mirror is not a database-consistent snapshot or a substitute for tested logical restores.

Dry-run activation does not write the generated Borgmatic or Home Assistant files. Run `python3 scripts/test-mini-safety.py` for synthetic safety checks. Local health-export and tt-coach repositories/binaries still need manual provisioning; this configuration does not create them.

Docker Compose 2.30 or newer is required for `env_file.format = raw`. Runtime credentials now use `secrets.env`, distinct from project `.env`, and commands suppress automatic project dotenv loading. Dollar signs, quotes and backslashes remain literal. Newline-containing values are rejected explicitly rather than misparsed. Old `.env` files are left untouched for manual review; no private keys or credentials are removed automatically.

Raw environment-file behavior is documented in the [Docker Compose service reference](https://docs.docker.com/reference/compose-file/services/#format).
