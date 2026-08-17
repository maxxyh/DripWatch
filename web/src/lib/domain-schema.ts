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
