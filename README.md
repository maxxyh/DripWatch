# ☕️ DripWatch

*Because "I'll just remember the grind setting" has never once been true.*

DripWatch is a native iOS coffee-brewing companion for people who take their pourover (and
espresso) seriously enough to actually close the loop: **brew parameters → taste → next
recipe.** It's not a logging notebook that politely forgets you the moment you close the app —
it's the thing that notices your last brew was under-extracted and nudges your next dial-in.

Built with SwiftUI and SwiftData, syncing quietly to Supabase in the background so your brew
history survives a dropped phone, a new device, or three months of "I'll deal with it later."

## Why it exists

Every home barista has lived this loop:

1. Brew something great.
2. Forget exactly what you did.
3. Spend the next bag reverse-engineering yesterday's luck.

DripWatch exists to break step 2. The bean is the hero of its own character card — roaster,
origin, roast date, a photo of the bag — and every brew remembers its recipe in full, so the
next cup is a decision, not a guess.

## What's inside

- 🫘 **Beans** — the character card for every bag, photos included.
- 🌊 **Pourover-first capture** — with espresso along for the ride, method-aware.
- 🎛️ **Absolute, reproducible grind** — `grinder · dial(±clicks)`, no vague vibes.
- 🔁 **The signature loop** — see exactly what changed between brews and why it mattered.
- ☁️ **Quiet cloud sync** — Supabase Postgres as server truth, private storage for photos.

## Getting oriented

Project guidance lives in [`AGENTS.md`](AGENTS.md) — architecture, build/test commands, and the
conventions this repo runs on. `CLAUDE.md` is a symlink to the same file, so agents and humans
read from one source of truth.

Deeper topics live in `docs/`:

- [Supabase sync architecture and operations](docs/supabase-sync.md)
- [Engineering process and session learnings](docs/engineering-process.md)
- [Web PWA setup, deployment, security, and offline behavior](docs/web-pwa.md)
- [Testing the web PWA](docs/web-pwa-testing.md)
- [Supabase schema and setup](supabase/README.md)
- [Backup and restore runbook](supabase/backup/README.md)

## Quick build

```bash
xcodebuild -project DripWatch.xcodeproj -scheme DripWatch \
  -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' \
  -configuration Debug build
```

Target: iOS 17+, iPhone 16 simulator, iOS 18.2 SDK. Full build, test, and web PWA instructions
are in [`AGENTS.md`](AGENTS.md).

---

*No cup was over-extracted in the making of this README.*
