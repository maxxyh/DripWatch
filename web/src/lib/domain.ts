import type {
  BeanRow,
  BrewRow,
  GrindSetting,
  Recipe,
  Taste,
} from "./domain-schema";

export type {
  GrindSetting,
  Pour,
  Recipe,
  Taste,
  BeanRow,
  BrewRow,
  BeanPhotoRow,
  GrinderRow,
  Notebook,
} from "./domain-schema";

export function photoUrl(
  bucket: "bean-photos" | "brew-photos",
  path: string | null,
) {
  return path
    ? `/api/photos/${bucket}/${path.split("/").map(encodeURIComponent).join("/")}`
    : null;
}
export const emptyRecipe = (): Recipe => ({ pours: [] });
export const newPourover = (): Recipe => ({
  pours: [],
  waterTempC: 92,
  bloomTimeSec: 30,
  ratio: 15,
  pourCount: 3,
});
export const emptyTaste = (): Taste => ({
  positives: [],
  negatives: [],
  balance: {},
});
export const hasTaste = (taste: Taste) =>
  taste.positives.length > 0 ||
  taste.negatives.length > 0 ||
  Object.keys(taste.balance).length > 0 ||
  taste.rating !== undefined ||
  !!taste.note?.trim();
export const asPlanSeed = (recipe: Recipe): Recipe => ({
  ...recipe,
  shotTimeSec: undefined,
  totalDrawdownSec: undefined,
});
export const grind = (recipe: Recipe): GrindSetting | undefined =>
  recipe.grinderName
    ? {
        grinderName: recipe.grinderName,
        major: recipe.grindMajor ?? 0,
        clickOffset: recipe.grindClickOffset ?? 0,
      }
    : undefined;
export const effectiveWater = (r: Recipe) =>
  r.totalWaterGrams ??
  (r.doseGrams !== undefined && r.ratio !== undefined
    ? r.doseGrams * r.ratio
    : undefined);
export function setTotalWater(r: Recipe, grams?: number): Recipe {
  const out = { ...r };
  if (!grams || grams <= 0) {
    if (out.doseGrams && out.doseGrams > 0) out.ratio = undefined;
    else out.totalWaterGrams = undefined;
    return out;
  }
  if (out.doseGrams && out.doseGrams > 0) {
    out.ratio = grams / out.doseGrams;
    out.totalWaterGrams = undefined;
  } else out.totalWaterGrams = grams;
  return out;
}
export function reconcileWater(r: Recipe): Recipe {
  if (!r.doseGrams || r.doseGrams <= 0 || r.totalWaterGrams === undefined)
    return r;
  return {
    ...r,
    ratio: r.totalWaterGrams / r.doseGrams,
    totalWaterGrams: undefined,
  };
}
export function canonicalizePourTimings(recipe: Recipe): Recipe {
  const bloomTimeSec =
    recipe.bloomTimeSec ??
    recipe.pours.find((pour) => pour.order === 2)?.startSec;
  const pours = recipe.pours.map((pour) =>
    pour.order === 1
      ? { ...pour, startSec: 0 }
      : pour.order === 2
        ? { ...pour, startSec: bloomTimeSec }
        : pour,
  );
  return { ...recipe, bloomTimeSec, pours };
}
export function setBloomTime(recipe: Recipe, seconds?: number): Recipe {
  const pours =
    seconds === undefined
      ? recipe.pours.map((pour) =>
          pour.order === 2 ? { ...pour, startSec: undefined } : pour,
        )
      : recipe.pours;
  return canonicalizePourTimings({ ...recipe, bloomTimeSec: seconds, pours });
}
const round5 = (n: number) => Math.max(0, Math.round(n / 5) * 5);
export function suggestedTargets(r: Recipe, count: number): number[] {
  const total = effectiveWater(r);
  if (count <= 0 || !total || total <= 0) return [];
  let values: number[];
  if (
    count >= 2 &&
    r.doseGrams &&
    r.doseGrams > 0 &&
    round5(r.doseGrams * 3) < total
  ) {
    const bloom = round5(r.doseGrams * 3),
      step = (total - bloom) / (count - 1);
    values = Array.from({ length: count }, (_, i) =>
      i === 0 ? bloom : bloom + step * i,
    );
  } else
    values = Array.from({ length: count }, (_, i) => (total * (i + 1)) / count);
  values = values.map(round5);
  values[count - 1] = total;
  return values;
}
export const ratioText = (n: number) => String(Math.round(n * 100) / 100);
export const gramText = (n: number) =>
  Number.isInteger(n) ? String(n) : n.toFixed(1);
export const pricePerGramSGD = (
  priceSGD: number | null,
  bagSizeGrams: number | null,
) => {
  if (
    priceSGD === null ||
    priceSGD <= 0 ||
    bagSizeGrams === null ||
    bagSizeGrams <= 0
  )
    return null;
  const result = priceSGD / bagSizeGrams;
  return Number.isFinite(result) ? result : null;
};
export const pricePerGramTextSGD = (price: number, locale?: string) =>
  `S$${
    price < 1_000
      ? price.toFixed(2)
      : new Intl.NumberFormat(locale, {
          notation: "compact",
          maximumSignificantDigits: 3,
        }).format(price)
  }/g`;
export const timeText = (n: number) =>
  `${Math.floor(n / 60)}:${String(n % 60).padStart(2, "0")}`;
export function secondsFromDigits(raw: string) {
  const digits = raw.replace(/\D/g, "");
  if (!digits) return undefined;
  if (digits.length <= 2) return Number(digits);
  return Number(digits.slice(0, -2)) * 60 + Number(digits.slice(-2));
}
export function liveTimeEntry(raw: string) {
  const digits = raw.replace(/\D/g, "").replace(/^0+/, "").slice(0, 4);
  const seconds = secondsFromDigits(digits);
  return { text: seconds === undefined ? "" : timeText(seconds), seconds };
}
export function singlePendingPlanPatch(
  method: "pourover" | "espresso",
  draft: Recipe | null,
) {
  return {
    pending_next_pourover: method === "pourover" ? draft : null,
    pending_next_espresso: method === "espresso" ? draft : null,
  };
}
export function grindDisplay(g: GrindSetting, includeName = true) {
  const major = Number.isInteger(g.major)
    ? String(g.major)
    : g.major.toFixed(1);
  const offset =
    g.clickOffset === 0
      ? ""
      : g.clickOffset > 0
        ? `(+${g.clickOffset})`
        : `(−${Math.abs(g.clickOffset)})`;
  return `${includeName ? `${g.grinderName} · ` : ""}${major}${offset}`;
}
export function recipeSummary(r: Recipe) {
  const p: string[] = [];
  const g = grind(r);
  if (g) p.push(grindDisplay(g, false));
  if (r.waterTempC !== undefined) p.push(`${r.waterTempC}°`);
  if (r.doseGrams !== undefined)
    p.push(
      r.yieldGrams !== undefined
        ? `${gramText(r.doseGrams)}→${gramText(r.yieldGrams)}g`
        : `${gramText(r.doseGrams)}g dose`,
    );
  if (r.doseGrams === undefined && r.yieldGrams !== undefined)
    p.push(`${gramText(r.yieldGrams)}g yield`);
  if (r.ratio !== undefined) p.push(`1:${ratioText(r.ratio)}`);
  const water = effectiveWater(r);
  if (r.doseGrams !== undefined && water !== undefined)
    p.push(`${gramText(water)}g water`);
  if (r.pourCount !== undefined)
    p.push(`${r.pourCount} pour${r.pourCount === 1 ? "" : "s"}`);
  if (r.shotTimeSec !== undefined) p.push(`${r.shotTimeSec}s`);
  if (r.bloomTimeSec !== undefined) p.push(`${r.bloomTimeSec}s bloom`);
  if (r.totalDrawdownSec !== undefined)
    p.push(`TDD ${timeText(r.totalDrawdownSec)}`);
  if (r.preInfusionSec !== undefined) p.push(`${r.preInfusionSec}s pre-infuse`);
  if (r.surfWaitSec !== undefined) p.push(`${r.surfWaitSec}s surf`);
  if (r.steamModeSec !== undefined) p.push(`${r.steamModeSec}s steam`);
  return p.join(" · ");
}
/// Full brew detail as Markdown — bean facts, the complete recipe, how it tasted, and the
/// planned next brew — for pasting into an AI (or a friend) for brewing advice. Mirrors the iOS
/// app's BrewMarkdown so a brew copied from either platform reads the same.
export function brewMarkdown(
  bean: BeanRow,
  brew: BrewRow,
  plannedNext?: Recipe | null,
): string {
  const sections: string[] = [];
  const name = bean.name.trim() || "Untitled bean";
  const methodLabel = brew.method_raw === "pourover" ? "Pourover" : "Espresso";
  sections.push(`# ${name} — ${methodLabel}`);
  sections.push(
    [
      bean.roaster_name?.trim(),
      new Intl.DateTimeFormat(undefined, { dateStyle: "medium" }).format(
        new Date(brew.brewed_at),
      ),
    ]
      .filter(Boolean)
      .join(" · "),
  );
  const facts = beanFactLines(bean);
  if (facts.length) sections.push(`**Bean**\n${facts.join("\n")}`);
  sections.push(
    `**Recipe**\n${recipeLines(brew.recipe, brew.method_raw).join("\n")}`,
  );
  const taste = tasteLines(brew.taste);
  if (taste.length) sections.push(`**Taste**\n${taste.join("\n")}`);
  if (plannedNext)
    sections.push(
      `**Planned next brew**\n${recipeLines(plannedNext, brew.method_raw).join("\n")}`,
    );
  return sections.join("\n\n");
}
function beanFactLines(bean: BeanRow): string[] {
  const lines: string[] = [];
  const add = (label: string, value?: string | null) => {
    const v = value?.trim();
    if (v) lines.push(`- ${label}: ${v}`);
  };
  const origin = [bean.region, bean.country]
    .filter((x) => x?.trim())
    .join(", ");
  add("Origin", origin || undefined);
  add("Farm", bean.farm);
  add("Variety", bean.varietal);
  add("Process", bean.process);
  add("Roast", bean.roast_level);
  if (bean.roast_date)
    add(
      "Roasted",
      new Intl.DateTimeFormat(undefined, { dateStyle: "medium" }).format(
        new Date(bean.roast_date),
      ),
    );
  if (bean.roaster_notes?.trim())
    add(
      "Roaster notes",
      bean.roaster_notes
        .split(",")
        .map((n) => n.trim())
        .filter(Boolean)
        .join(", "),
    );
  return lines;
}
function recipeLines(r: Recipe, method: "pourover" | "espresso"): string[] {
  r = canonicalizePourTimings(r);
  const lines: string[] = [];
  const g = grind(r);
  if (g) lines.push(`- Grind: ${grindDisplay(g)}`);
  if (method === "espresso") {
    if (r.doseGrams !== undefined) lines.push(`- Dose: ${gramText(r.doseGrams)} g`);
    if (r.yieldGrams !== undefined)
      lines.push(`- Yield: ${gramText(r.yieldGrams)} g`);
    if (r.doseGrams && r.yieldGrams)
      lines.push(`- Ratio: 1:${ratioText(r.yieldGrams / r.doseGrams)}`);
    if (r.shotTimeSec !== undefined)
      lines.push(`- Shot time: ${timeText(r.shotTimeSec)}`);
    if (r.preInfusionSec !== undefined)
      lines.push(`- Pre-infusion: ${r.preInfusionSec}s`);
    if (r.surfWaitSec !== undefined) lines.push(`- Surf wait: ${r.surfWaitSec}s`);
    if (r.steamModeSec !== undefined)
      lines.push(`- Steam mode: ${r.steamModeSec}s`);
    if (r.waterTempC !== undefined) lines.push(`- Temp: ${r.waterTempC}°C`);
  } else {
    if (r.waterTempC !== undefined) lines.push(`- Temp: ${r.waterTempC}°C`);
    if (r.doseGrams !== undefined) lines.push(`- Dose: ${gramText(r.doseGrams)} g`);
    if (r.ratio !== undefined) lines.push(`- Ratio: 1:${ratioText(r.ratio)}`);
    const water = effectiveWater(r);
    if (water !== undefined) lines.push(`- Water: ${gramText(water)} g`);
    if (r.pourCount !== undefined) lines.push(`- Pours: ${r.pourCount}`);
    if (r.bloomTimeSec !== undefined)
      lines.push(`- Bloom: ${timeText(r.bloomTimeSec)}`);
    if (r.totalDrawdownSec !== undefined)
      lines.push(`- Drawdown (TDD): ${timeText(r.totalDrawdownSec)}`);
    const pours = [...r.pours]
      .sort((a, b) => a.order - b.order)
      .filter(
        (p) =>
          p.toGrams !== undefined ||
          p.startSec !== undefined ||
          p.style?.trim(),
      );
    if (pours.length) {
      lines.push("- Pour-by-pour:");
      for (const p of pours) {
        const parts: string[] = [];
        if (p.startSec !== undefined)
          parts.push(
            p.endSec !== undefined
              ? `${timeText(p.startSec)}–${timeText(p.endSec)}`
              : timeText(p.startSec),
          );
        if (p.toGrams !== undefined) parts.push(`→ ${gramText(p.toGrams)} g`);
        if (p.style?.trim()) parts.push(`(${p.style.trim()})`);
        lines.push(`  - #${p.order}: ${parts.join(" ")}`);
      }
    }
  }
  if (r.notes?.trim()) lines.push(`- Notes: ${r.notes.trim()}`);
  if (!lines.length) lines.push("- (no parameters recorded)");
  return lines;
}
function tasteLines(t: Taste): string[] {
  const lines: string[] = [];
  if (t.positives.length) lines.push(`- Good: ${t.positives.join(", ")}`);
  if (t.negatives.length) lines.push(`- Off: ${t.negatives.join(", ")}`);
  const balance = (["acidity", "sweetness", "bitterness", "body"] as const)
    .filter((axis) => t.balance[axis] !== undefined)
    .map((axis) => `${axis} ${t.balance[axis]}/5`);
  if (balance.length) lines.push(`- Balance: ${balance.join(", ")}`);
  if (t.rating)
    lines.push(
      `- Rating: ${"★".repeat(t.rating)}${"☆".repeat(Math.max(0, 5 - t.rating))}`,
    );
  if (t.note?.trim()) lines.push(`- Note: ${t.note.trim()}`);
  return lines;
}
export function brewDiff(a: Recipe, b: Recipe) {
  const o: string[] = [];
  const ga = grind(a),
    gb = grind(b);
  if (ga && gb) {
    if (
      ga.grinderName === gb.grinderName &&
      ga.major === gb.major &&
      ga.clickOffset !== gb.clickOffset
    ) {
      const d = gb.clickOffset - ga.clickOffset;
      o.push(
        `${Math.abs(d)} click${Math.abs(d) === 1 ? "" : "s"} ${d > 0 ? "finer" : "coarser"}`,
      );
    } else if (ga.grinderName !== gb.grinderName)
      o.push(`grinder → ${gb.grinderName}`);
    else if (ga.major !== gb.major)
      o.push(`grind ${grindDisplay(ga, false)} → ${grindDisplay(gb, false)}`);
  }
  const change = (
    x: number | undefined,
    y: number | undefined,
    f: (x: number, y: number) => string,
  ) => {
    if (x !== undefined && y !== undefined && x !== y) o.push(f(x, y));
  };
  change(
    a.waterTempC,
    b.waterTempC,
    (x, y) => `${Math.abs(y - x)}° ${y > x ? "hotter" : "cooler"}`,
  );
  change(a.ratio, b.ratio, (x, y) => `1:${ratioText(x)} → 1:${ratioText(y)}`);
  change(
    a.doseGrams,
    b.doseGrams,
    (x, y) => `${y > x ? "+" : "−"}${gramText(Math.abs(y - x))}g dose`,
  );
  change(
    a.yieldGrams,
    b.yieldGrams,
    (x, y) => `${y > x ? "+" : "−"}${gramText(Math.abs(y - x))}g yield`,
  );
  change(a.shotTimeSec, b.shotTimeSec, (x, y) => `shot ${x}s → ${y}s`);
  change(
    a.preInfusionSec,
    b.preInfusionSec,
    (x, y) => `pre-infuse ${x}s → ${y}s`,
  );
  change(a.surfWaitSec, b.surfWaitSec, (x, y) => `surf ${x}s → ${y}s`);
  change(a.steamModeSec, b.steamModeSec, (x, y) => `steam ${x}s → ${y}s`);
  change(a.pourCount, b.pourCount, (x, y) => `${x} → ${y} pours`);
  change(
    a.totalDrawdownSec,
    b.totalDrawdownSec,
    (x, y) => `TDD ${timeText(x)} → ${timeText(y)}`,
  );
  return o;
}
export function normalizeTerm(value: string) {
  return value
    .trim()
    .split(/\s+/)
    .filter(Boolean)
    .map((word) =>
      word
        .split("-")
        .map((part) => {
          if (!part) return part;
          if (/\d/.test(part)) return part;
          const letters = Array.from(part).filter((character) =>
            /\p{L}/u.test(character),
          );
          if (
            letters.length > 0 &&
            letters.length <= 4 &&
            part === part.toLocaleUpperCase()
          )
            return part;
          const lower = part.toLocaleLowerCase();
          return lower.charAt(0).toLocaleUpperCase() + lower.slice(1);
        })
        .join("-"),
    )
    .join(" ");
}
export function normalizeTerms(values: string[]) {
  const seen = new Set<string>();
  return values
    .map(normalizeTerm)
    .filter(
      (v) =>
        v &&
        !seen.has(v.toLocaleLowerCase()) &&
        seen.add(v.toLocaleLowerCase()),
    );
}
