# iOS reference screenshots

Real screenshots of the native app (dark mode, iPhone), captured 2026-08-19, for comparing the
web PWA's visual density and typography against iOS — not just its source. Reading
`RecipeEditor.swift` tells you *what fields exist*; these tell you *how little chrome iOS puts
around them*. Check this folder before reworking any PWA screen that has a native counterpart,
and add to it (compressed, as below) whenever a redesign turns up a fresh visual gap worth
keeping around.

| File | Screen |
| --- | --- |
| `shelf.jpg` | Shelf grid |
| `bean-detail-character-card.jpg` | Bean detail: character card + Pourover/Espresso buttons |
| `bean-detail-plan-card.jpg` | Bean detail: pending-plan card |
| `history-timeline.jpg` | Bean detail: history rows, icon chips + proportional pour timeline |
| `recipe-editor-grind.jpg` | New Pourover, Recipe tab: grind picker with quick-pick chips |
| `recipe-editor-pour-breakdown.jpg` | New Pourover, Recipe tab, scrolled: pour breakdown expanded |
| `brewing-phase-readout.jpg` | New Pourover, Brewing tab: live stat-grid readout + stopwatch |

## What these show that the source alone doesn't

- **One continuous card of plain rows**, not a form of individually bordered inputs. The whole
  Recipe tab — grind, temp, dose, ratio, water, pours, bloom, TDD, and the expanded pour
  breakdown — is a single card. Each row is icon/label on the left, a big legible value on the
  right, with a `−`/`+` stepper cluster only where a quick nudge is the common move. No nested
  card-within-card, no border around every field.
- **Pour breakdown rows are plain typed text, not boxed steppers.** `recipe-editor-pour-breakdown.jpg`:
  `#1  start – 0:15         60 g`, then a lighter `style / note (centre, aggressive…)` placeholder
  underneath — no border, no +/− buttons, just inline fields in a tight list.
  `web/src/components/recipe-editor.tsx`'s pour rows currently use the shared `Field`/`Input`
  components uniformly, which is why they still read as a "form" next to this.
- **The grinder picker is quick-pick chips above a text field**, not just a free-text input with an
  HTML `<datalist>` — `recipe-editor-grind.jpg` shows known grinders as tappable chips (checkmark
  on the selected one), the text field below only for typing a new one.
- **The Brewing tab's readout is a distinct big stat-grid**, not the icon-chip pills used in
  history (`RecipeReadout.swift`'s `pill()`). `brewing-phase-readout.jpg`: large bold
  `92°  20g  1:15  300g` with small caption labels underneath, `POUR PLAN` as a section label with
  an inline `bloom 0:45 · 3 pours · TDD 2:15` summary, then the same plain pour rows as the editor.
  The PWA's brewing-phase "Follow the recipe" card (`brew-editor.tsx`) currently reuses the
  history-style `RecipeChips` pills here instead of this stat-grid — a second, different gap from
  the pour-breakdown one above.

## Adding more

Keep these small — resize to ~480px wide, JPEG quality ~75-80 is plenty for a layout/spacing
reference and keeps this folder out of the way of the app's own build size:

```bash
node -e "require('sharp')('source.png').resize({width:480}).jpeg({quality:78}).toFile('docs/ios-reference/name.jpg')"
```
