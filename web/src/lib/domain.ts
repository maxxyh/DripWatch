import { z } from "zod";

const optionalNumber = z.number().finite().optional();
const optionalInt = z.number().int().optional();
export const grindSettingSchema = z.object({
  grinderName: z.string(),
  major: z.number(),
  clickOffset: z.number().int(),
});
export type GrindSetting = z.infer<typeof grindSettingSchema>;
export const pourSchema = z.object({
  id: z.uuid(),
  order: z.number().int(),
  toGrams: optionalNumber,
  startSec: optionalInt,
  endSec: optionalInt,
  style: z.string().optional(),
});
export const recipeSchema = z.object({
  grinderName: z.string().optional(),
  grindMajor: optionalNumber,
  grindClickOffset: optionalInt,
  waterTempC: optionalInt,
  doseGrams: optionalNumber,
  ratio: optionalNumber,
  totalWaterGrams: optionalNumber,
  pourCount: optionalInt,
  bloomTimeSec: optionalInt,
  totalDrawdownSec: optionalInt,
  notes: z.string().optional(),
  pours: z.array(pourSchema),
  yieldGrams: optionalNumber,
  shotTimeSec: optionalInt,
  preInfusionSec: optionalInt,
  surfWaitSec: optionalInt,
  steamModeSec: optionalInt,
});
export type Recipe = z.infer<typeof recipeSchema>;
export const tasteBalanceSchema = z.object({
  acidity: optionalInt,
  sweetness: optionalInt,
  bitterness: optionalInt,
  body: optionalInt,
});
export const tasteSchema = z.object({
  positives: z.array(z.string()),
  negatives: z.array(z.string()),
  balance: tasteBalanceSchema,
  rating: optionalInt,
  note: z.string().optional(),
});
export type Taste = z.infer<typeof tasteSchema>;
const timestamp = z.iso.datetime({ offset: true });
const syncFields = {
  id: z.uuid(),
  created_at: timestamp,
  updated_at: timestamp,
  deleted_at: timestamp.nullable(),
};
export const beanSchema = z.object({
  ...syncFields,
  name: z.string(),
  roaster_name: z.string().nullable(),
  country: z.string().nullable(),
  region: z.string().nullable(),
  farm: z.string().nullable(),
  varietal: z.string().nullable(),
  process: z.string().nullable(),
  roast_level: z.string().nullable(),
  roast_date: timestamp.nullable(),
  roaster_notes: z.string().nullable(),
  my_flavor_tags: z.array(z.string()),
  finished_at: timestamp.nullable(),
  pending_next_pourover: recipeSchema.nullable(),
  pending_next_espresso: recipeSchema.nullable(),
});
export const brewSchema = z.object({
  ...syncFields,
  brewed_at: timestamp,
  method_raw: z.enum(["pourover", "espresso"]),
  brewers: z.array(z.string()),
  recipe: recipeSchema,
  taste: tasteSchema,
  next_recipe_draft: recipeSchema.nullable(),
  photo_path: z.string().nullable(),
  bean_id: z.uuid().nullable(),
});
export const beanPhotoSchema = z.object({
  ...syncFields,
  order: z.number().int().nonnegative(),
  bean_id: z.uuid().nullable(),
  remote_path: z.string().nullable(),
});
export const grinderSchema = z.object({
  ...syncFields,
  name: z.string(),
  stepless: z.boolean(),
});
export const grinderMutationSchema = grinderSchema
  .partial()
  .required({ id: true });
export type BeanRow = z.infer<typeof beanSchema>;
export type BrewRow = z.infer<typeof brewSchema>;
export type BeanPhotoRow = z.infer<typeof beanPhotoSchema>;
export type GrinderRow = z.infer<typeof grinderSchema>;
export type Notebook = {
  beans: BeanRow[];
  brews: BrewRow[];
  beanPhotos: BeanPhotoRow[];
  grinders: GrinderRow[];
  loadedAt: string;
};

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
export const timeText = (n: number) =>
  `${Math.floor(n / 60)}:${String(n % 60).padStart(2, "0")}`;
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
