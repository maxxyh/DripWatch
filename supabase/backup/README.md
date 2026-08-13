# DripWatch Supabase backups

`scripts/backup-supabase.sh` creates one timestamped, mode-`0700` backup
directory per run. It requires two environment variables:

```sh
export DRIPWATCH_DB_URL='postgresql://USER:PERCENT_ENCODED_PASSWORD@HOST:5432/postgres'
export DRIPWATCH_BACKUP_DIR='/Volumes/DripWatchBackups'
scripts/backup-supabase.sh
```

`DRIPWATCH_BACKUP_DIR` must already exist, be an absolute path, not resolve to
`/`, and be writable. The script does not create a destination outside the
timestamped run directory. It never prints or writes the database URL, and no
secret belongs in this repository.

## Prerequisites

- Install and authenticate the Supabase CLI (`supabase login`).
- Run the command from the DripWatch repository so `supabase/config.toml` is
  available.
- Link the repository to the hosted project before copying Storage:
  `supabase link --project-ref YOUR_PROJECT_REF`.
- The database URL must be the direct/appropriate Postgres connection URL for
  the target project. Percent-encode reserved characters in credentials.
- `supabase db dump` runs `pg_dump` in a container in the current CLI workflow,
  so Docker Desktop may be required.

The script interrogates `supabase --help`, `supabase db dump --help`, and
`supabase storage cp --help` before doing work. It fails closed if required
flags disappear. Current CLI help marks Storage copy as experimental; the
script detects `--experimental` and passes it when present. If a future CLI no
longer advertises that flag, it omits it.

## Backup layout

Each run is retained at:

```text
$DRIPWATCH_BACKUP_DIR/YYYYMMDDTHHMMSSZ/
├── database-schema.sql
├── database-data.sql
├── manifest.txt
└── storage/
    ├── bean-photos/
    └── brew-photos/
```

The two database files are intentional: the current CLI's default `db dump`
does not include table data, so the script runs a schema dump and a separate
`--data-only` dump. `storage` is excluded by Supabase's managed-schema dump;
the two bucket trees preserve the photo objects themselves.

Retention defaults to keeping all completed and incomplete runs. The script
contains no deletion or pruning step. Use an external, separately reviewed
retention policy only if the backup volume needs lifecycle management.

## launchd setup

The template is
`supabase/backup/launchd/com.dripwatch.supabase-backup.plist.template`.
launchd does not expand `$VAR` references in plist values, so keep the
template unchanged and create a private local copy outside the repository:

```sh
mkdir -p "$HOME/Library/Logs/DripWatch"
cp supabase/backup/launchd/com.dripwatch.supabase-backup.plist.template \
  "$HOME/Library/LaunchAgents/com.dripwatch.supabase-backup.plist"
```

Edit that local copy's explicit placeholders for the script path, repository
working directory, `DRIPWATCH_DB_URL`, `DRIPWATCH_BACKUP_DIR`, and log paths.
Treat the local plist as a secret-bearing file; keep its permissions private
and do not commit it. Validate it, then load it for the current user:

```sh
plutil -lint "$HOME/Library/LaunchAgents/com.dripwatch.supabase-backup.plist"
chmod 600 "$HOME/Library/LaunchAgents/com.dripwatch.supabase-backup.plist"
launchctl bootstrap "gui/$(id -u)" \
  "$HOME/Library/LaunchAgents/com.dripwatch.supabase-backup.plist"
launchctl kickstart -k "gui/$(id -u)/com.dripwatch.supabase-backup"
```

The schedule is daily at 03:30 local time. The kickstart command performs an
immediate smoke run; inspect the launchd error log and newest timestamped
directory afterward. To unload it:

```sh
launchctl bootout "gui/$(id -u)/com.dripwatch.supabase-backup"
```

## Restore

Restore into a new or explicitly emptied target project whenever possible.
The dump is a logical SQL backup, not a point-in-time clone. First establish
the target project and install/link the Supabase CLI there. Review the dump
and declarative schema for the target project's auth model before applying
either.

Restore the dumped schema first. Then apply the declarative schema; its
idempotent declarations restore the private buckets and normalize DripWatch's
policies and conflict triggers. Finally restore the rows:

```sh
psql "$TARGET_DRIPWATCH_DB_URL" \
  --file '/path/to/YYYYMMDDTHHMMSSZ/database-schema.sql'
psql "$TARGET_DRIPWATCH_DB_URL" \
  --file 'supabase/schemas/dripwatch.sql'
psql "$TARGET_DRIPWATCH_DB_URL" \
  --file '/path/to/YYYYMMDDTHHMMSSZ/database-data.sql'
```

The `psql` commands above intentionally use an environment variable rather
than putting a credential in a script or plist. Review the SQL and target
permissions first; a logical dump may contain
ownership/grant statements that need adjustment for a different project.

Finally, upload each local bucket tree to the matching target bucket using the
CLI syntax advertised by the target installation. With the current syntax:

```sh
supabase storage cp --recursive --linked --experimental \
  '/path/to/YYYYMMDDTHHMMSSZ/storage/bean-photos' \
  'ss:///bean-photos'
supabase storage cp --recursive --linked --experimental \
  '/path/to/YYYYMMDDTHHMMSSZ/storage/brew-photos' \
  'ss:///brew-photos'
```

Run `supabase storage cp --help` first: `--experimental` is required by the
current CLI help and may be removed when the feature graduates. Verify object
counts, app photo references, RLS behavior, and a representative image before
considering the restore complete.
