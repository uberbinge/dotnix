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
