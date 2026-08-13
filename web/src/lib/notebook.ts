import { requireSession } from "./auth";
import {
  beanPhotoSchema,
  beanSchema,
  brewSchema,
  grinderSchema,
  grinderMutationSchema,
  recipeSchema,
  tasteSchema,
  type Notebook,
} from "./domain";
import { supabase } from "./supabase";
type PageQuery = {
  order(column: string, options?: { ascending?: boolean }): PageQuery;
  range(
    from: number,
    to: number,
  ): Promise<{ data: unknown[] | null; error: Error | null }>;
};
type Selectable = { select(columns: string): PageQuery };

async function loadRows(table: Table, orderColumn: string, ascending: boolean) {
  const db = supabase();
  const rows: unknown[] = [];
  const pageSize = 500;
  for (let from = 0; ; from += pageSize) {
    const query = (db.from(table) as unknown as Selectable)
      .select("*")
      .order(orderColumn, { ascending })
      .order("id", { ascending: true });
    const page = await query.range(from, from + pageSize - 1);
    if (page.error) throw page.error;
    rows.push(...(page.data ?? []));
    if (!page.data || page.data.length < pageSize) break;
  }
  return rows;
}
export async function loadNotebook(): Promise<Notebook> {
  await requireSession();
  const [beans, brews, photos, grinders] = await Promise.all([
    loadRows("beans", "updated_at", false),
    loadRows("brews", "brewed_at", false),
    loadRows("bean_photos", "order", true),
    loadRows("grinders", "name", true),
  ]);
  return {
    beans: beanSchema.array().parse(beans),
    brews: brewSchema.array().parse(brews),
    beanPhotos: beanPhotoSchema.array().parse(photos),
    grinders: grinderSchema.array().parse(grinders),
    loadedAt: new Date().toISOString(),
  };
}
export type Table = "beans" | "brews" | "bean_photos" | "grinders";
const allowedColumns: Record<Table, Set<string>> = {
  beans: new Set([
    "id",
    "created_at",
    "deleted_at",
    "name",
    "roaster_name",
    "country",
    "region",
    "farm",
    "varietal",
    "process",
    "roast_level",
    "roast_date",
    "roaster_notes",
    "my_flavor_tags",
    "finished_at",
    "pending_next_pourover",
    "pending_next_espresso",
  ]),
  brews: new Set([
    "id",
    "created_at",
    "deleted_at",
    "brewed_at",
    "method_raw",
    "brewers",
    "recipe",
    "taste",
    "next_recipe_draft",
    "photo_path",
    "bean_id",
  ]),
  bean_photos: new Set([
    "id",
    "created_at",
    "deleted_at",
    "order",
    "bean_id",
    "remote_path",
  ]),
  grinders: new Set(["id", "created_at", "deleted_at", "name", "stepless"]),
};

function safeMutation(table: Table, row: Record<string, unknown>) {
  if (typeof row.id !== "string")
    throw new Error("A valid row ID is required.");
  let safe = Object.fromEntries(
    Object.entries(row).filter(([key]) => allowedColumns[table].has(key)),
  );
  if (table === "brews") {
    if ("recipe" in safe) safe.recipe = recipeSchema.parse(safe.recipe);
    if ("taste" in safe) safe.taste = tasteSchema.parse(safe.taste);
    if ("next_recipe_draft" in safe && safe.next_recipe_draft !== null)
      safe.next_recipe_draft = recipeSchema.parse(safe.next_recipe_draft);
  }
  if (table === "beans") {
    for (const key of ["pending_next_pourover", "pending_next_espresso"])
      if (key in safe && safe[key] !== null)
        safe[key] = recipeSchema.parse(safe[key]);
  }
  if (table === "grinders") safe = grinderMutationSchema.parse(safe);
  return safe;
}
export async function upsertWithConflict(
  table: Table,
  row: Record<string, unknown>,
  originalUpdatedAt?: string,
) {
  await requireSession();
  const db = supabase();
  row = safeMutation(table, row);
  const originalTime = originalUpdatedAt
    ? Date.parse(originalUpdatedAt)
    : Number.NaN;
  const now = new Date(
    Number.isFinite(originalTime)
      ? Math.max(Date.now(), originalTime + 1)
      : Date.now(),
  ).toISOString();
  const relation = db.from(table) as unknown as {
    insert(value: Record<string, unknown>): {
      select(): { single(): Promise<{ data: unknown; error: Error | null }> };
    };
    update(value: Record<string, unknown>): {
      eq(
        column: string,
        value: string,
      ): {
        eq(
          column: string,
          value: string,
        ): {
          select(): {
            maybeSingle(): Promise<{ data: unknown; error: Error | null }>;
          };
        };
      };
    };
    select(columns: string): {
      eq(
        column: string,
        value: string,
      ): { maybeSingle(): Promise<{ data: unknown; error: Error | null }> };
    };
  };
  if (!originalUpdatedAt) {
    const result = await relation
      .insert({ ...row, updated_at: now })
      .select()
      .single();
    if (result.error) throw result.error;
    return { ok: true as const, row: result.data };
  }
  const result = await relation
    .update({ ...row, updated_at: now })
    .eq("id", String(row.id))
    .eq("updated_at", originalUpdatedAt)
    .select()
    .maybeSingle();
  if (result.error) throw result.error;
  if (!result.data) {
    const current = await relation
      .select("updated_at")
      .eq("id", String(row.id))
      .maybeSingle();
    if (current.error) throw current.error;
    return {
      ok: false as const,
      conflict: true as const,
      current: current.data,
    };
  }
  return { ok: true as const, row: result.data };
}
