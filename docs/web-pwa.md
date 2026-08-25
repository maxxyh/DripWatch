# DripWatch web PWA

The mobile-first PWA in `web/` is a responsive companion to the native app. It shares Supabase
rows, embedded JSON shapes, private photo buckets, client UUIDs, stale-write semantics, and soft
deletion. Bag OCR, lexicon management, realtime, push, per-user permissions, and offline editing
are intentionally deferred.

## Local development

Use Node 22 or newer. Copy the example without committing the result:

```bash
cd web
cp .env.example .env.local
npm ci
npm run dev
```

Required server-only variables are `SUPABASE_URL`, `SUPABASE_ANON_KEY`,
`DRIPWATCH_PASSCODE`, and `DRIPWATCH_SESSION_SECRET` (at least 32 random characters). Never use a
service-role key or a `NEXT_PUBLIC_` prefix. Rotating the passcode invalidates existing sessions;
rotating the session secret invalidates every session. Configure Vercel Firewall rate limiting on
`/api/auth/login`; the application has no durable distributed rate limiter of its own.

`DRIPWATCH_SESSION_SECRET` only signs/verifies sessions for the server instance that issued
them — it never needs to match anyone else's, so each person can generate their own random
32+ character string.

For which `SUPABASE_URL`/`SUPABASE_ANON_KEY` to use (the shared hosted project vs. a fully
isolated local Supabase stack) and how to verify a change, see
[Testing the web PWA](web-pwa-testing.md).

## Vercel and offline behavior

Create a separate Vercel project rooted at `web/`, select Node 22+, and configure the four
variables. `web/vercel.json` pins the Next.js framework preset so a project first created through
the CLI does not inherit the static “Other” output behavior. No database schema change is required.

`web/vercel.json` also pins `regions` to the Supabase project's region (`sin1`, matching
`ap-southeast-1`). Every request to `/api/notebook` and `/api/photos/...` makes at least one
Postgres round trip plus, for photos, a Storage download, so running the function far from the
database turns each one into a cross-region round trip — measured at ~1-9s per request on
`iad1` (US East) against a Singapore project, dropping to well under a second once colocated. If
the Supabase project ever moves region, update this value to match.

The Vercel project's Git integration (Project Settings → Git) must have **Root Directory** set to
`web`, not the repo root — the Next.js app lives in the `web/` subdirectory alongside the native
Xcode project, and a build at the repo root finds no `package.json` and fails. Once connected,
pushing a branch alone only gets you a pass/fail GitHub commit status (green "Vercel — Deployment
has completed"), and its target link opens the Vercel inspector, which needs account access.
**Open a PR** to get the actual preview URL: with "Pull Request Comments" enabled (the default),
Vercel's bot comments the clickable preview URL directly on the PR, viewable by any collaborator
with repo access — no Vercel account needed. The deployment itself is publicly reachable; access
is still gated by DripWatch's own shared passcode, not Vercel account permissions.

The standalone manifest derives its icons from the native app. The service worker uses cache-first
for immutable assets and network-first fallback for the last notebook snapshot and viewed photos.
Protected caches are isolated by a random signed-session scope and become unavailable when the
session lease expires. Viewed photos are bounded to the newest 120 objects and an approximate
100 MB budget per session; starting a new session purges prior session scopes. It never caches
mutations, auth routes, failures, or RSC payloads. Offline
mode is persistently read-only. Reconnect reloads server state before editing. Logout removes the
local snapshot, expires the cookie, and purges protected caches. Cached data is not encrypted at
rest; avoid installing on an untrusted shared device.

On top of the service worker's network-first `/api/notebook` handling, the app layer
(`useNotebook` in `src/components/notebook-app.tsx`) also paints the last `localStorage` snapshot
immediately on mount — before the background `refresh()` fetch resolves — whenever it exists and
its session lease hasn't expired, then swaps in the live response when it lands. This is a
perceived-loading-speed optimization on top of the offline fallback, not a change to it: the
network request always still fires, mutation entry points stay disabled (`revalidating`) until
that fetch confirms freshness, and the "Offline snapshot" banner only appears if the fetch
actually fails, never during a routine revalidation. `e2e/notebook-cache.spec.ts` covers this by
mocking `/api/notebook` with an artificial delay and asserting the cached content renders well
before it resolves.

Core web mutations use client UUIDs and soft deletion. A bean has at most one active planned next
brew across both methods; creating or updating one method's plan clears the other method slot.
The plan appears once above the bean history, never as a card attached to an individual historical
brew. Starting a new brew inserts its row and consumes the matching pending plan before the
timer/taste phases become reachable. Bean
deletion soft-deletes its active brews and photo rows before the parent; this multi-row flow is
recoverable but not transactionally atomic through PostgREST. Bean and brew photos are normalized
in the browser and guarded by canonical, record-linked proxy paths. Replacement objects may remain
orphaned after a later stale-write conflict and must not be deleted speculatively.

When no plan exists, bean detail keeps a quiet “Next brew / Plan a change” entry below the brew
buttons; it opens the existing full recipe planner, seeded from the newest brew (or the default
pourover recipe when history is empty). The newest history card alone shows a dashed “Add tasting
notes?” suggestion when its taste is completely empty, linking directly to that brew's Taste tab.
Older untasted brews are intentionally left unprompted.

Once a brew is started, its date, recipe, observed time, taste, and photo reference autosave with
stale-write guards. Planning from the newest brew updates the bean's single active pending plan;
the legacy per-brew `next_recipe_draft` field is no longer used by the PWA. Brewing mode retains
the absolute recipe, cumulative
pour targets and timing/style details, manual espresso technique, and roaster notes; history uses
the same persisted pour rows rather than regenerating them.

Bean edits use the same term normalization as iOS: fact fields are title-cased while digit-bearing
codes and short uppercase acronyms keep their spelling, comma lists are case-insensitively deduped,
and roaster brand casing is preserved. Saved and newly selected bag photos share one ordered draft,
so the hero order is visible before save. The bean editor also captures optional SGD price and
labeled bag size in grams; shelf cards and bean detail derive and show the SGD-per-gram value for
quick comparison, matching iOS. Both editors offer 100 g, 200 g, and 250 g bag-size shortcuts. `RecipeEditor` also remembers newly typed grinders and
their stepped/stepless classification through the guarded mutation API. Numeric recipe controls
use iOS-style decrement/increment buttons and mobile numeric keypads; signed controls retain
negative entry. Observed drawdown and shot time use the native digit-entry convention, so `230`
becomes `2:30` while the stopwatch remains available. Time inputs place the caret at the end when
clicked so right-shifting digit entry cannot accidentally retain trailing zeros. Across recipe
editing, live brewing, history, and exports, pour one always starts at `0:00`; pour two's start is
the bloom time and edits through either field update the same synced `bloomTimeSec` value. While
tasting, "Previous notes" mirrors
`BrewCaptureView.swift`'s `PreviousNotesView`: the last few brews' terms are grouped one card per
brewed date (collapsed to the most recent, "Show N more" reveals the rest) and keep positive/negative
coloring, rather than one undifferentiated flat list of chips.

Local development is read-only when `SUPABASE_URL` points to a hosted project. Mutation and photo
upload routes return `403` unless Supabase is local or `ALLOW_REMOTE_DEV_MUTATIONS=1` is explicitly
set. The canonical Vercel production deployment is also allowed (`VERCEL_ENV=production`), while
local production-mode servers and preview deployments remain guarded. Visual verification should
keep the guard enabled; remote opt-in is reserved for deliberate manual data work.

Photo uploads are also decoded at the server boundary and rejected unless they are valid JPEGs
whose width and height are both at most 1400 pixels. On the read side, `/api/photos/[bucket]/...`
resizes via `sharp` when called with a `?w=` (and optional `?q=`) query param, clamped to
16-1400px / 40-90 quality; `src/lib/image-loader.ts` is the `next/image` custom loader that
appends those params, so every display context requests roughly the size it renders at instead of
always the full upload. Both `w`/`q` and the resulting `sharp()` decode share the same 1400px
`limitInputPixels` cap as upload validation — necessary because the anonymous Supabase policies
(see "Required future migration" below) let `anon` write `storage.objects` and the referencing
`bean_photos`/`brews` rows directly, bypassing the upload endpoint's own size/dimension checks, so
the read path cannot assume every stored object was validated. Because the proxy path embeds a
sha256 content hash, a given `(hash, width, quality)` tuple's output never changes; the route
returns `Cache-Control: private, max-age=31536000, immutable` and checks `If-None-Match` before
touching Storage or sharp, rather than the `no-cache` used previously. Supabase database definitions in
`src/lib/database.types.ts` are generated from the hosted project; run `npm run types:generate`
after schema changes. The script writes through a temporary file so an authentication or network
failure cannot truncate the committed definitions.

The web can display only photos represented by a Supabase `bean_photos.remote_path`. A legacy
native-only `Bean.bagPhoto` value was never part of the Postgres contract; if such a bag has not
completed the iOS migration/upload, the PWA correctly shows a placeholder until the native client
syncs a `BeanPhoto` row and object.

## Client bundle hygiene

`src/lib/domain-schema.ts` holds the Zod schemas used to validate rows in `src/lib/notebook.ts`
(server-only, reached only from `src/app/api/notebook/route.ts`). `src/lib/domain.ts` holds the
plain formatting/calculation helpers and re-exported types that client components use. Keep this
split: importing `zod` from a module that any `"use client"` component also imports pulls the
whole validation runtime into the shared client bundle even when the client only touches the pure
helpers, since a mutually-recursive schema definition is not something bundlers can safely
tree-shake out of an otherwise-used file. This previously added ~300 KB (minified) to the app's
largest client chunk. Verify with `npx next experimental-analyze --output` (writes to
`.next/diagnostics/analyze`, or omit `--output` for the interactive view) after `npm run build`,
and confirm the client chunks contain no `zod` bytes with `grep -rl zod .next/static/chunks`.
`next/image`, `next/font`, and named `lucide-react` imports (auto-optimized by Next) are already
used correctly; keep doing so in new code.

A second pattern in the same vein: `BeanDetail` and everything exclusively reachable from it
(`CharacterCard`, `PlanCard`, `RecipeReadout`, `HistoryCard`, and transitively `RecipeEditor` with
its `@base-ui/react` `Select`/`ToggleGroup`, plus the `AlertDialog` family) previously lived inside
`src/components/notebook-app.tsx` alongside `Shelf`/`BeanCard`, which both `/` and `/beans/[id]`
import. Next's route-based splitting cannot separate two components sharing one static module
graph, so `/` shipped BeanDetail's dialog/editor code even though only `/beans/[id]` renders it.
It now lives in `src/components/bean-detail.tsx` (default export) and is loaded from
`notebook-app.tsx` via `next/dynamic()`, so it code-splits into its own chunk fetched only when a
bean detail page actually mounts. `photoUrl()`, needed by both files, moved to `src/lib/domain.ts`.

Caveat when verifying this kind of split: the bundle analyzer's per-route "All Route Modules"
total (and its module count) sums every module reachable from the route through both sync and
async edges — it does not exclude `next/dynamic()`-split code, so it will not shrink, and may even
tick up slightly from loadable-wrapper bookkeeping, even when the split is working correctly.
Judge it instead by confirming the split chunk's files (listed in
`.next/server/app/<route>/react-loadable-manifest.json`) share zero files with `rootMainFiles` in
the sibling `build-manifest.json`, or, most directly, by diffing the actual `_next/static/chunks/*`
requests captured for a cold load of the route before and after the change. This split measured
~19% (~42 KB gzipped) off the real JS fetched for a cold `/` load.

When saving an analyzer snapshot for a before/after comparison (`cp -r .next/diagnostics/analyze
<name>`), put it outside the repo (e.g. `/tmp`) rather than under `web/`: `.next/` is gitignored
but an ad-hoc copy elsewhere isn't, so it silently becomes an untracked directory of static HTML
that pollutes `npm run lint` and sits in the tree unreviewed. A leftover `web/before/` snapshot
from verifying the split above had to be deleted for exactly this reason.

## Required future migration

The shared passcode is a temporary interface gate while anonymous Supabase policies support iOS.
Before sensitive or multi-tenant use, add authenticated notebook membership to both clients,
ownership/membership predicates to every table and object, and revoke anonymous grants.
