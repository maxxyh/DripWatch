# DripWatch Supabase schema

`schemas/dripwatch.sql` is the declarative source of truth for the five public
tables, RLS policies, grants, and private photo buckets. It intentionally does
not include a timestamped migration: generate one only after reviewing the
schema with the Supabase CLI.

```sh
supabase db diff -f create_dripwatch_schema
```

The current policies are a documented no-auth prototype: every `anon` client
shares the notebook and can select, insert, and update rows and photo objects.
There is no hard-delete grant. Add authenticated ownership rules before using
this schema for more than one user.

Active grinder names are unique by `lower(btrim(name))`. The grinder-deduplication migration
soft-deletes later case/whitespace duplicates, preserves the oldest display spelling, and retains
a stepless classification recorded on any duplicate. Recipe JSON keeps its historical spelling.

## App configuration

After creating the hosted project and applying the schema, copy the local-only
configuration template and fill in the project's URL and **publishable** key:

```sh
cp Config/Secrets.xcconfig.example Config/Secrets.xcconfig
```

`Config/Secrets.xcconfig` is ignored by Git. The publishable key is expected to
ship in the app; never put a `service_role` or secret key in the iOS target.
On the first configured launch, an existing local notebook is queued and pushed
before the server is pulled. A fresh install with no local rows pulls first.

## Backups

Backup tooling lives in [`supabase/backup/README.md`](backup/README.md), with
the executable at [`scripts/backup-supabase.sh`](../scripts/backup-supabase.sh)
and a launchd template under `supabase/backup/launchd/`. The script requires
`DRIPWATCH_DB_URL` and `DRIPWATCH_BACKUP_DIR`, writes schema, data, and both
photo buckets into a UTC-timestamped directory, and keeps all runs by default.
It validates the installed Supabase CLI's help output before invoking database
or Storage commands; Storage copy is currently marked experimental by the CLI.
