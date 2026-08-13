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

## Vercel and offline behavior

Create a separate Vercel project rooted at `web/`, select Node 22+, and configure the four
variables. No database schema change is required.

The standalone manifest derives its icons from the native app. The service worker uses cache-first
for immutable assets and network-first fallback for the last notebook snapshot and viewed photos.
Protected caches are isolated by a random signed-session scope and become unavailable when the
session lease expires. Viewed photos are bounded to the newest 120 objects and an approximate
100 MB budget per session; starting a new session purges prior session scopes. It never caches
mutations, auth routes, failures, or RSC payloads. Offline
mode is persistently read-only. Reconnect reloads server state before editing. Logout removes the
local snapshot, expires the cookie, and purges protected caches. Cached data is not encrypted at
rest; avoid installing on an untrusted shared device.

Core web mutations use client UUIDs and soft deletion. Starting a new brew inserts its row and
consumes the method-specific pending plan before the timer/taste phases become reachable. Bean
deletion soft-deletes its active brews and photo rows before the parent; this multi-row flow is
recoverable but not transactionally atomic through PostgREST. Bean and brew photos are normalized
in the browser and guarded by canonical, record-linked proxy paths. Replacement objects may remain
orphaned after a later stale-write conflict and must not be deleted speculatively.

Once a brew is started, its date, recipe, observed time, taste, photo reference, and next-brew
draft autosave with stale-write guards. The newest brew of each method also keeps the bean's
method-specific pending plan synchronized. Brewing mode retains the absolute recipe, cumulative
pour targets and timing/style details, manual espresso technique, and roaster notes; history uses
the same persisted pour rows rather than regenerating them.

Bean edits use the same term normalization as iOS: fact fields are title-cased while digit-bearing
codes and short uppercase acronyms keep their spelling, comma lists are case-insensitively deduped,
and roaster brand casing is preserved. Saved and newly selected bag photos share one ordered draft,
so the hero order is visible before save. `RecipeEditor` also remembers newly typed grinders and
their stepped/stepless classification through the guarded mutation API.

Photo uploads are also decoded at the server boundary and rejected unless they are valid JPEGs
whose width and height are both at most 1400 pixels. Supabase database definitions in
`src/lib/database.types.ts` are generated from the hosted project; run `npm run types:generate`
after schema changes. The script writes through a temporary file so an authentication or network
failure cannot truncate the committed definitions.

The web can display only photos represented by a Supabase `bean_photos.remote_path`. A legacy
native-only `Bean.bagPhoto` value was never part of the Postgres contract; if such a bag has not
completed the iOS migration/upload, the PWA correctly shows a placeholder until the native client
syncs a `BeanPhoto` row and object.

## Verification

```bash
cd web
npm run typecheck
npm run lint
npm test
npm run build
npx playwright install chromium webkit
npm run test:e2e
```

With disposable test data and real environment values, also verify two-session stale conflicts, bean and photo CRUD,
pourover and espresso capture, plan consumption, soft deletion, offline fallback, reconnect
refresh, and logout cache clearing.

## Required future migration

The shared passcode is a temporary interface gate while anonymous Supabase policies support iOS.
Before sensitive or multi-tenant use, add authenticated notebook membership to both clients,
ownership/membership predicates to every table and object, and revoke anonymous grants.
