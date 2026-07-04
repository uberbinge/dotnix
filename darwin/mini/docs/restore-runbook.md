# Restore Runbook

This runbook is intentionally conservative. Restores should first go into a
staging directory, not over live service data.

## Source Of Truth

- Service definitions: `dotnix/darwin/mini/services/`
- Borgmatic config: `dotnix/darwin/mini/borgmatic.nix`
- Runtime borgmatic directory: `~/.config/media-server/borgmatic`
- Runtime logs: `~/.config/media-server/borgmatic/logs`
- Secrets: 1Password
- Media volume: `/Volumes/4tb`
- Local backup volume: `/Volumes/2tb`

## Backup Coverage

Immich:

- `/Volumes/4tb/immich/library`
- `/Volumes/4tb/immich/postgres`
- latest SQL dump staged from Immich's backup directory when present

Jellyfin:

- `/Volumes/4tb/jellyfin/config`
- `/Volumes/4tb/jellyfin/jellyfin-books`
- `/Volumes/4tb/jellyfin/jellyfin-library`

Paperless:

- `/Volumes/4tb/paperless`
- `/Volumes/4tb/paperless/db-dumps`

The scheduled `paperless-db-dump` launchd job writes a fresh dump before the
daily Paperless backup. Manual `borgmatic-backup paperless` and
`borgmatic-backup all` also create a fresh dump before borgmatic runs.

Paperless PostgreSQL remains on the Docker named volume until the manual
migration in `paperless-migration.md` is completed.

## Non-Destructive Verification

List archives:

```bash
borgmatic-list immich
borgmatic-list jellyfin
borgmatic-list paperless
```

Check repositories:

```bash
borgmatic-check immich
borgmatic-check jellyfin
borgmatic-check paperless
```

These commands should not delete data.

## Staged Restore Pattern

Use a staging directory outside live service paths:

```text
/private/tmp/mini-restore/<service>/
```

Do not restore directly into `/Volumes/4tb/...` until the staged restore has
been inspected.

Recommended flow:

1. Confirm the service is healthy enough to understand what is being restored.
2. List archives and pick the exact archive by name.
3. Extract into a staging directory.
4. Inspect file counts, sizes, timestamps, and expected critical files.
5. For databases, prefer restoring from database-safe dumps when available.
6. Stop the target service only after staged data is verified.
7. Move existing live data aside instead of deleting it.
8. Copy staged data into place.
9. Start the service and verify application-level behavior.
10. Keep the old live data copy until the restore is proven.

Any command that overwrites, removes, prunes, or replaces live data requires
explicit approval immediately before it is run.

## Paperless Restore Notes

Paperless document files and metadata must agree. Restore the media/data paths
and the PostgreSQL database dump from the same backup window where possible.

Before enabling external PostgreSQL storage:

```nix
services.mediaServer.paperless.useExternalPostgresDataDir = true;
services.mediaServer.paperless.externalPostgresMigrationConfirmed = true;
```

verify that `/Volumes/4tb/paperless/postgres` contains the migrated database
state and that a fresh dump exists under `/Volumes/4tb/paperless/db-dumps`.

## Immich Restore Notes

Immich includes both media and PostgreSQL data. Prefer an application-supported
database restore from the latest SQL dump when possible. Raw PostgreSQL files
are useful as an additional recovery path but should not be the only restore
method tested.

## Retirement Dependency

Do not retire `backups-mini-server` completely until:

- Nix-managed backups have recent successful archives.
- At least one staged restore has been tested.
- Leaked or committed credentials have been rotated.
- `borgmatic-dashboard` is reading Nix-managed logs.
