# DripWatch

A native iOS (SwiftUI + SwiftData) coffee brewing companion. It replaces a paper brewing
notebook — but the point isn't logging, it's the **feedback loop**: brew parameters → taste →
the recipe to try next time.

## Product north star

- **Pourover first** (the owner is an expert here); **espresso** capture is now also in
  (method-aware `RecipeEditor` / `BrewCaptureView`). Bag **OCR** (Vision) auto-fills fields.
- The **bean is the hero**: each bean is a "character card" (bag photo + roaster-style facts).
- **One Recipe, one editor**: a brew *has* a recipe, and the planned "next brew" *is* a draft
  recipe edited in the same UI while tasting. The next brew seeds from that draft.
- **Grind is absolute + reproducible** — `1Zpresso J · 3(−1)` (grinder · dial(±clicks), where
  `+` = finer/clockwise, `−` = coarser/anticlockwise). The "N clicks coarser/finer than last
  time" is a *computed annotation only*, never a replacement for the absolute value.
- **Structured but optional/progressive**: a simple recipe line is the default; per-pour
  breakdown and taste balance are folded away until wanted.
- Multi-user sync (pourover is collaborative) is a **later phase**; the data model is already
  sync-shaped so it's additive, not a rewrite.

Full plan: `/Users/maxx/.claude/plans/hi-claude-let-s-product-brainstorming-kind-kay.md`.

## Architecture

- **Persistence**: SwiftData (`@Model` classes: `Bean`, `Brew`, `Grinder`). Value types
  (`Recipe`, `Pour`, `GrindSetting`, `Taste`, `TasteBalance`) are `Codable` structs embedded on
  the models — this is what lets one `Recipe` be reused for both a brew and its next-draft.
- **Sync-readiness**: everything conforms to `Syncable` (`id`, `createdAt`, `updatedAt`,
  `deletedAt` soft-delete). All attributes have defaults and relationships are optional — the
  shape CloudKit will require later. Deletes are soft (set `deletedAt`), not hard.
- **The signature feature** is `BrewDiff` (`Features/Loop/BrewDiff.swift`): the param delta
  between consecutive brews of a bean, shown as an annotation above the always-visible absolute
  recipe (`RecipeReadout`).

### Source layout (`DripWatch/`)

```
DripWatchApp.swift          @main + ModelContainer (sync-ready config)
Models/                     Bean, Brew, Grinder, Recipe, Pour, GrindSetting, Taste, Syncable
Features/
  Beans/                    Shelf grid, add-bean sheet, detail, character card, taste dots
  Recipe/                   RecipeEditor (THE reusable editor) + GrindPicker
  Capture/                  PouroverBrewView (log → taste → draft-next inline)
  Loop/                     BrewHistoryView + BrewDiff (history log + delta annotation)
DesignSystem/               Theme, WrapLayout, SampleData (DEBUG-only)
```

The Xcode project uses **synchronized file groups** (Xcode 16, `objectVersion 77`): any Swift
file added under `DripWatch/` is picked up automatically — no `.pbxproj` edits per file.

## Design conventions (HIG-aligned)

- **Aesthetic**: monochrome, shadcn-inspired. A near-neutral zinc base, hairline-bordered
  cards (`Theme.radius` 14, whisper shadow), and a **single red accent** (`Theme.accent`).
  Color enters *only* through bag photos, the accent, and the red-tinted "next brew" plan
  card. Bean-photo placeholders are neutral on purpose.
- **Colors**: text uses semantic colors (`Color(.label)`, `.secondary`); every container/
  accent color goes through `Theme` via `Color.adaptive(light:dark:)` so Dark Mode is correct.
  Never hardcode a one-appearance color (the one deliberate exception — the brew-count badge's
  `.white` over a photo — is commented). Positive taste = `Theme.sage` (emerald), negative =
  `Theme.clay` (rose), each paired with a +/− symbol.
- **Params typography**: numeric brew params render in `Font.param(...)` (SF Mono) for an
  instrument-data feel; uppercase metadata labels use `.overline()` (tracked, muted).
- **Typography**: semantic text styles only (`.headline`, `.subheadline`, `.caption`) — no
  hardcoded point sizes, so Dynamic Type works.
- **Touch targets**: use `.hitTarget()` (≥44pt) on small tappable controls.
- **Haptics**: `Haptics.tap/select/success` for physical / selection / outcome feedback.
- **Meaning is never color-alone**: taste chips carry a `+`/`−` symbol; balance uses filled
  dots + a text value.

## Build & run

Simulator: **iPhone 16** (iOS 17+ deployment target, iOS 18.2 SDK).

```bash
xcodebuild -project DripWatch.xcodeproj -scheme DripWatch \
  -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' \
  -configuration Debug build

xcrun simctl install "iPhone 16" <DerivedData>/…/DripWatch.app
xcrun simctl launch "iPhone 16" com.dripwatch.DripWatch
```

### DEBUG verification launch args (no manual tapping needed)

`SampleData.swift` and the debug hooks in `BeanListView`/`BeanDetailView` respond to:

- `-seedSampleData 1` — seed the real notebook's Voyager (22/06 → 23/06) + Crimson beans
- `-openFirstBean 1` — navigate straight to a brewed bean
- `-openEspressoBean 1` — navigate to a bean with an espresso brew (Crimson)
- `-openBrewSheet 1` — auto-present the brew capture sheet
- `-scrollToHistory 1` — scroll to the history log

Screenshot: `xcrun simctl io "iPhone 16" screenshot out.png`. Toggle appearance with
`xcrun simctl ui "iPhone 16" appearance dark|light`.

> Note: when the user drives this machine via **mobile remote control**, computer-use
> Simulator control can't get its approval dialog — use `simctl` + the launch args above.

## Testing

Unit tests live in `DripWatchTests/` (Swift Testing — `import Testing`, `@Test`). Run:

```bash
xcodebuild test -project DripWatch.xcodeproj -scheme DripWatch \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

Coverage is on the pure logic: `BrewDiff` (grind/temp/ratio/yield/shot-time deltas, and the
rule that a finer/coarser *direction* is only asserted for the same grinder + dial),
`GrindSetting` display/offset, `Recipe` (shotRatio / effectiveWater / isEmpty incl. blank
pours / summaryLine), `BagOCR.parse` (columnar + inline layouts, value-consumption, name
heuristic), and `Bean` per-method seeding/pending.

> Note: the test bundle is hosted in the app, and a hosted SwiftData `ModelContainer` crashes
> in this setup — `BeanSeedTests` therefore exercises the model on **standalone objects** (no
> container), wiring `bean.brews` directly. Keep new model-logic tests container-free.

## Conventions for changes

- Keep new persisted types `Syncable` (id/createdAt/updatedAt/deletedAt) and give every stored
  property a default so the CloudKit phase stays additive.
- Reuse `RecipeEditor` anywhere a recipe is edited — do not fork a second recipe UI.
- Grind: always display the full absolute `GrindSetting.display`; deltas are annotations.
- New user-facing params belong on the `Recipe` struct as optionals, surfaced in the simple
  line if everyday, otherwise behind the progressive breakdown.
