# DripWatch

Native iOS coffee-brewing companion built with SwiftUI and SwiftData. The product is the
feedback loop—brew parameters → taste → next recipe—not merely a logging notebook.

`AGENTS.md` is canonical project guidance. `CLAUDE.md` is a symlink to this file.

## Mandatory living-documentation contract

After **every piece of work**, review this file and the relevant `docs/` pages. Update them in
the same change whenever architecture, behavior, operational steps, constraints, or verified
learnings changed. This documentation review is mandatory even when no edit is ultimately
needed. Keep this file concise; put durable topic detail in `docs/<topic>.md` and link it here.

## Product invariants

- Pourover first; espresso capture is also method-aware.
- The bean is the hero: bag photos plus roaster facts form its character card.
- One reusable `RecipeEditor`; a brew owns a recipe and its planned next brew is a draft recipe.
- Grind is absolute and reproducible: `grinder · dial(±clicks)`. Deltas are annotations only.
- Structured but progressive: everyday recipe line first, detail only when requested.
- Meaning is never color-only. Preserve Dynamic Type, ≥44pt targets, semantic colors, and
  `Theme`-based adaptive surfaces.

## Architecture at a glance

- **Local persistence:** SwiftData models `Bean`, `BeanPhoto`, `Brew`, `Grinder`, and
  `LexiconTerm`. Embedded value types such as `Recipe` and `Taste` remain `Codable` structs.
- **Cloud sync:** Supabase Postgres is server truth when online; private Supabase Storage buckets
  hold compressed bean and brew photos. See [docs/supabase-sync.md](docs/supabase-sync.md).
- **Sync identity:** every persisted model is `Syncable` with stable `id`, `createdAt`,
  `updatedAt`, and soft-delete `deletedAt`. Stored properties need safe defaults.
- **Signature loop:** `Features/Loop/BrewDiff.swift` computes parameter changes between brews;
  `RecipeReadout` always keeps the absolute recipe visible.

### Source layout

```text
DripWatchApp.swift          App/container setup and sync startup/foreground refresh
Models/                     SwiftData models and embedded Codable values
Features/                   Beans, Capture, Recipe, Loop, Scan
Sync/                       DTOs, remote seam, Supabase transport, outbox, bootstrap, engine
DesignSystem/               Theme, layouts, DEBUG sample data
DripWatchTests/             Swift Testing suites, including sync transport/DTO/outbox coverage
supabase/                   Declarative hosted schema, backup docs, launchd template
scripts/                    Operational scripts
web/                        Next.js PWA, guarded API boundary, domain tests, PWA assets
```

The project uses Xcode 16 synchronized file groups; Swift files added under `DripWatch/` are
picked up automatically. The Supabase Swift package is pinned and its lockfile is committed.

## Build and verification

Target: iOS 17+, iPhone 16 simulator, iOS 18.2 SDK.

```bash
xcodebuild -project DripWatch.xcodeproj -scheme DripWatch \
  -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' \
  -configuration Debug build

xcodebuild test -project DripWatch.xcodeproj -scheme DripWatch \
  -destination 'platform=iOS Simulator,name=iPhone 16'

cd web
npm ci
npm run typecheck && npm run lint && npm test && npm run build
npm run test:e2e
```

DEBUG launch arguments: `-seedSampleData 1`, `-openFirstBean 1`, `-openEspressoBean 1`,
`-openBrewSheet 1`, and `-scrollToHistory 1`.

The hosted test bundle can hang/crash when a SwiftData `ModelContainer` is created inside it;
keep pure model-logic tests container-free and wire standalone relationships directly. For sync
work, also verify against the real Supabase project and run security/performance advisors.

## Change conventions

- Every user mutation of a syncable model must call `markDirty()`; deletes use `softDelete()`.
- Never hard-delete synced records or expose a service-role/secret key in the app.
- Reuse `RecipeEditor`; do not fork a second recipe-editing interface.
- Always display full `GrindSetting.display`; deltas never replace the absolute setting.
- New recipe parameters are optional. Put everyday values in the simple line and specialist
  values behind progressive disclosure.
- Preserve unrelated user work in a dirty worktree. Do not stage local secrets.
- Before handoff: build, run proportional tests, verify external state when touched, review the
  diff independently for complex work, perform the mandatory documentation review, then commit.

## Topic library

- [Supabase sync architecture and operations](docs/supabase-sync.md)
- [Engineering process and session learnings](docs/engineering-process.md)
- [Web PWA setup, deployment, security, and offline behavior](docs/web-pwa.md)
- [Supabase schema and setup](supabase/README.md)
- [Backup and restore runbook](supabase/backup/README.md)
