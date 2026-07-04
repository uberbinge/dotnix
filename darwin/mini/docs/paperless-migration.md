# Paperless Storage And Backup Runbook

Paperless currently uses an internal Docker named volume for PostgreSQL unless
`services.mediaServer.paperless.useExternalPostgresDataDir` is enabled.

The target layout is:

```text
/Volumes/4tb/paperless/
  data/
  media/
  export/
  consume/
  postgres/
  db-dumps/
```

## Current Safe State

The Nix config now creates a scheduled `paperless-db-dump` job at 04:45. It
writes database-safe dumps to:

```text
/Volumes/4tb/paperless/db-dumps/
```

Borgmatic includes that dump directory in the Paperless backup.

## Migration Caution

Do not enable `useExternalPostgresDataDir` until the existing Docker named
volume has been copied or restored into `postgresDataDir`. Enabling it early can
start Paperless with an empty database directory.

The Nix module has a second safety switch:

```nix
services.mediaServer.paperless.externalPostgresMigrationConfirmed = true;
```

The build will fail if `useExternalPostgresDataDir` is enabled without this
acknowledgement.

## Manual Migration Outline

These steps are intentionally not automated.

1. Stop Paperless.
2. Create a fresh database dump with `paperless-db-dump`.
3. Confirm the dump exists under `/Volumes/4tb/paperless/db-dumps/`.
4. Copy or restore the existing Docker `pgdata` volume into
   `/Volumes/4tb/paperless/postgres`.
5. Set:

   ```nix
   services.mediaServer.paperless.useExternalPostgresDataDir = true;
   services.mediaServer.paperless.externalPostgresMigrationConfirmed = true;
   ```

6. Rebuild the mini config and start Paperless.
7. Verify documents, users, tags, correspondents, and recent imports.
8. Only after multiple successful starts and a tested restore should the old
   Docker named volume be considered removable.

Do not remove the old Docker volume without explicit approval and a verified
backup.
