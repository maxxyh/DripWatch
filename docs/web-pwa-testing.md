# Testing the web PWA

Environment setup and verification steps for `web/`. See [docs/web-pwa.md](web-pwa.md) for the
app's architecture and behavior; this file is just how to stand it up and check it.

## Choosing a Supabase environment

`web/.env.local`'s `SUPABASE_URL` / `SUPABASE_ANON_KEY` can point at either of two complete
setups:

- **The shared hosted project.** Get the URL, anon key, and passcode from whoever manages the
  project (password manager, not Supabase org membership — this app has no per-user Supabase
  auth; see [Client bundle hygiene](web-pwa.md#client-bundle-hygiene) and `supabase/README.md`)
  and drop them into `.env.local`. Simplest option, but local dev reads/writes the same database
  as production and everyone else's preview deployments.
- **A local Supabase stack**, fully isolated per person, running via the Supabase CLI + a Docker
  runtime (Docker Desktop or the lighter [Colima](https://github.com/abiosoft/colima)):

  ```bash
  brew install supabase/tap/supabase colima docker   # one-time
  colima start                                        # one-time per reboot; starts the Docker daemon
  supabase start                                       # from the repo root, not web/
  ```

  `supabase start` applies `supabase/migrations/` and seeds `supabase/seed.sql` plus the sample
  bean/brew photos declared under `[storage.buckets.*]` in `supabase/config.toml` (real images
  from three beans in the shared notebook, kept small and photo-path-canonical — see the
  comments in `seed.sql` if you need to add more). It prints `SUPABASE_URL` (as `API_URL`) and
  `SUPABASE_ANON_KEY` (as `ANON_KEY`, the JWT one, not `PUBLISHABLE_KEY`) — copy those into
  `web/.env.local` along with any `DRIPWATCH_PASSCODE`/`DRIPWATCH_SESSION_SECRET` you like, since
  nothing here is a real secret. Supabase Studio is at the printed `STUDIO_URL` (typically
  `http://127.0.0.1:54323`) if you want to browse the local data directly.

  To reset to a clean seeded state at any point: `supabase db reset` (from the repo root). To
  stop the stack: `supabase stop`.

  After editing `supabase/schemas/dripwatch.sql`, regenerate the migration rather than hand
  editing `supabase/migrations/`:

  ```bash
  supabase db diff -f <descriptive_name>
  ```

  Check the generated file before trusting it — the diff tool doesn't pick up changes to the
  `storage.buckets` insert or the `storage.objects` policies at the bottom of
  `schemas/dripwatch.sql` (DML and policies on a platform-managed table, outside what it diffs),
  so that block currently has to be kept in sync by hand in the migration.

## Automated checks

```bash
cd web
npm run typecheck
npm run lint
npm test
npm run build
npx playwright install chromium webkit
npm run test:e2e
```

## Manual verification

With disposable test data and real environment values, also verify two-session stale conflicts,
bean and photo CRUD, pourover and espresso capture, plan consumption, soft deletion, offline
fallback, reconnect refresh, and logout cache clearing.
