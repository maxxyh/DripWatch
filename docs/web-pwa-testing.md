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

## Live-verifying UI changes without real network access

If direct HTTPS to Supabase is blocked (a sandboxed agent environment will 403 at the network
layer before any app code runs), don't skip live verification — drive the running dev server with
Playwright against mocked data instead of just reading the diff:

```js
const browser = await chromium.launch(); // add executablePath if the sandbox needs a pinned binary
const page = await browser.newPage();

// The app gates every route behind DRIPWATCH_PASSCODE; there's no bypass, so log in for real.
await page.goto("http://localhost:3000/login");
await page.fill('input[type="password"]', process.env.DRIPWATCH_PASSCODE);
await page.click('button[type="submit"]');
await page.waitForTimeout(1500); // the redirect after login isn't awaited by networkidle

// Mock /api/notebook for both shapes: GET returns the whole Notebook, POST is client-mutations.ts's
// mutate() call ({table, row, originalUpdatedAt}) and expects {row: <saved row>} back.
await page.route("**/api/notebook", async (route) => {
  const req = route.request();
  if (req.method() === "GET")
    return route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify(notebook) });
  const body = req.postDataJSON();
  route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify({ row: body.row }) });
});
```

From there, assert on real DOM (text content, input values, bounding boxes) and drive real
interactions (typing, Enter, clicks) rather than trusting that code compiling means the feature
works. This caught real bugs this way: a click target visually smaller than its hit-testable box
(photo viewer tap-to-dismiss), and a save handler that would have silently dropped an unrelated
field's existing value.

## Manual verification

With disposable test data and real environment values, also verify two-session stale conflicts,
bean and photo CRUD, pourover and espresso capture, plan consumption, soft deletion, offline
fallback, reconnect refresh, and logout cache clearing.
