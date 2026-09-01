# iOS reference screenshots

Real screenshots of the native app (dark mode, iPhone), captured 2026-08-19, for comparing the
web PWA's visual density and typography against iOS — not just its source. Reading
`RecipeEditor.swift` tells you *what fields exist*; these tell you *how little chrome iOS puts
around them*. Source-reading alone can also get *where* a field appears wrong: a view like
`BeanCardView` branches by `style` (`.shelf` vs `.full`), so a field read off the wrong branch
gets built as a PWA feature iOS never shows anywhere — that's exactly how the PWA grew a
`my_flavor_tags` shelf chip and edit-bean field with no real iOS counterpart, later removed once
real screenshots (and the user) caught it. Check this folder before reworking any PWA screen that
has a native counterpart, and add to it (compressed, as below) whenever a redesign turns up a
fresh visual gap worth keeping around.

| File | Screen |
| --- | --- |
| `shelf.jpg` | Shelf grid |
| `bean-detail-character-card.jpg` | Bean detail: character card + Pourover/Espresso buttons |
| `bean-detail-plan-card.jpg` | Bean detail: pending-plan card |
| `history-timeline.jpg` | Bean detail: history rows, icon chips + proportional pour timeline |
| `recipe-editor-grind.jpg` | New Pourover, Recipe tab: grind picker with quick-pick chips |
| `recipe-editor-pour-breakdown.jpg` | New Pourover, Recipe tab, scrolled: pour breakdown expanded |
| `brewing-phase-readout.jpg` | New Pourover, Brewing tab: live-edit stat grid, pour timings + stopwatch |
| `edit-bean-top.jpg` | Edit Bean: bag photo + scan, Bean name/roaster |
| `edit-bean-roaster-notes.jpg` | Edit Bean, scrolled: Process/Roast level chips, Roaster's Notes |

## What these show that the source alone doesn't

- **One continuous card of plain rows**, not a form of individually bordered inputs. The whole
  Recipe tab — grind, temp, dose, ratio, water, pours, bloom, TDD, and the expanded pour
  breakdown — is a single card. Each row is icon/label on the left, a big legible value on the
  right, with a `−`/`+` stepper cluster only where a quick nudge is the common move. No nested
  card-within-card, no border around every field. `web/src/components/recipe-editor.tsx` matches
  this now (`FieldRow`, full-width, icon + label left / compact stepper right) instead of the
  2-/3-column grids it used to force each field into — those grids were also the "squished, PWA
  doesn't use horizontal space well" complaint, since a 3-part stepper barely fits a half-width
  grid cell on a phone.
- **Pour breakdown rows are plain typed text, not boxed steppers.** `recipe-editor-pour-breakdown.jpg`:
  `#1  start – 0:15         60 g`, then a lighter `style / note (centre, aggressive…)` placeholder
  underneath — no border, no +/− buttons, just inline fields in a tight list.
  `web/src/components/recipe-editor.tsx` matches this now (borderless inline fields, a `#`/`start –
  end`/`to (g)` caption header once above the list rather than repeated per-row labels).
- **The grinder picker is quick-pick chips above a text field**, not just a free-text input with an
  HTML `<datalist>` — `recipe-editor-grind.jpg` shows known grinders as tappable chips (checkmark
  on the selected one), the text field below only for typing a new one, a `Stepless` switch (not a
  Stepped/Stepless tab pair), and a draggable ruler for stepless settings. `recipe-editor.tsx` and
  the new `grind-ruler.tsx`/`ui/switch.tsx` match this now; the old "Stepless grinders use the
  absolute dial…" explainer paragraph is gone (iOS never shows one).
- **The pourover dripper picker is visual but remains open-ended.** iOS and the PWA show the same
  three flat line-drawing presets—Hario V60 Ceramic, V60 Neo, and April Brewer—above an "Other
  dripper" text field. Selection is also expressed by border/checkmark and accessible state, never
  by color alone. The value is `Recipe.dripperName`, so it appears in history and planned recipes.
- **The Brewing tab is a legible live console, not a second planning form.** Its readout is a
  distinct big stat-grid, not the icon-chip pills used in
  history (`RecipeReadout.swift`'s `pill()`). `brewing-phase-readout.jpg`: large bold
  `92°  20g  1:15  300g` with small caption labels underneath. Temperature and final water are
  quiet 44pt live fields; dose, ratio, and the absolute grind readout remain locked. Bloom, each
  pour's start/end time, and cumulative water target are similarly editable in the enlarged
  `POUR PLAN` rows. Changing final water also changes the final cumulative pour target, preserving
  the recipe invariant. `brew-editor.tsx` matches this via `BrewStatGrid`/`PourPlanList` in
  `recipe-readout.tsx`; its large stopwatch digits are also the direct typed-time field, rather
  than duplicating the observation in a second input below. Read-only recipe summaries elsewhere
  still use their existing rendering.
- **The empty next-brew prompt belongs to the feedback loop.** On a newly added bean with no brew
  history it remains visible for discoverability, but is disabled and says “Available after first
  brew.” It becomes the active “Plan a change” prompt once the first brew exists.
- **Roaster's Notes is an Enter-to-add chip input**, not a comma-separated free-text field.
  `edit-bean-roaster-notes.jpg` shows existing notes (`Apricot`, `Honey`, `Apple Tart`) as pills
  with a sparkle icon, an `Add...` field with a return-arrow icon below, and a caption
  ("The roaster's tasting notes — shown on the shelf and while you taste") pinned under the card
  rather than inside it. `edit-bean-top.jpg` also confirms there is no "My flavor tags" field
  anywhere in Edit Bean — roaster notes is the only editable tasting-note surface on a bean.
  `web/src/components/bean-editor.tsx` matches this now (`TermField` for roaster notes, the
  unused flavor-tags field removed).
- **Edit Bean is a continuous card of plain rows per section (BEAN/ORIGIN/ROAST/ROASTER'S
  NOTES), not a form of individually bordered inputs.** Country/Region/Farm/Varietal are stacked
  full-width rows in one card, not a 2-column grid — the same "squished" complaint and fix as the
  Recipe tab (see above). Process and Roast level are wrapping quick-pick chips (`ChipRow`, the
  same pattern as the grinder picker's chips) below a free-text field, not a `ToggleGroup` — the
  old fixed-width, non-wrapping `ToggleGroup` row let its last chip ("Anaerobic") overflow off the
  edge of the screen instead of wrapping to a new line. `bean-editor.tsx` matches this now
  (`Section`/`PlainField`/`ChipRow`); `EditorFrame`'s page container also dropped a redundant
  `w-[calc(100%-var(--spacing)*10)]` that was double-shrinking the content width on top of `px-4`.

## Adding more

Keep these small — resize to ~480px wide, JPEG quality ~75-80 is plenty for a layout/spacing
reference and keeps this folder out of the way of the app's own build size:

```bash
node -e "require('sharp')('source.png').resize({width:480}).jpeg({quality:78}).toFile('docs/ios-reference/name.jpg')"
```
