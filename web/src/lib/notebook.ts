import { requireSession } from "./auth";
import {
  beanPhotoSchema,
  beanSchema,
  brewSchema,
  grinderSchema,
  type Notebook,
} from "./domain-schema";
import { supabase } from "./supabase";
import { safeMutation, type Table } from "./notebook-mutation";
export type { Table } from "./notebook-mutation";
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
