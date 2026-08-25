import {
  grinderMutationSchema,
  recipeSchema,
  tasteSchema,
} from "./domain-schema";
import { canonicalizePourTimings } from "./domain";

export type Table = "beans" | "brews" | "bean_photos" | "grinders";

const allowedColumns: Record<Table, Set<string>> = {
  beans: new Set([
    "id", "created_at", "deleted_at", "name", "roaster_name", "country",
    "region", "farm", "varietal", "process", "roast_level", "roast_date",
    "roaster_notes", "price_sgd", "bag_size_grams", "my_flavor_tags",
    "finished_at", "pending_next_pourover", "pending_next_espresso",
  ]),
  brews: new Set([
    "id", "created_at", "deleted_at", "brewed_at", "method_raw", "brewers",
    "recipe", "taste", "next_recipe_draft", "photo_path", "bean_id",
  ]),
  bean_photos: new Set([
    "id", "created_at", "deleted_at", "order", "bean_id", "remote_path",
  ]),
  grinders: new Set(["id", "created_at", "deleted_at", "name", "stepless"]),
};

export function safeMutation(table: Table, row: Record<string, unknown>) {
  if (typeof row.id !== "string")
    throw new Error("A valid row ID is required.");
  let safe = Object.fromEntries(
    Object.entries(row).filter(([key]) => allowedColumns[table].has(key)),
  );
  if (table === "brews") {
    if ("recipe" in safe)
      safe.recipe = canonicalizePourTimings(recipeSchema.parse(safe.recipe));
    if ("taste" in safe) safe.taste = tasteSchema.parse(safe.taste);
    if ("next_recipe_draft" in safe && safe.next_recipe_draft !== null)
      safe.next_recipe_draft = canonicalizePourTimings(
        recipeSchema.parse(safe.next_recipe_draft),
      );
  }
  if (table === "beans") {
    for (const key of ["pending_next_pourover", "pending_next_espresso"])
      if (key in safe && safe[key] !== null)
        safe[key] = canonicalizePourTimings(recipeSchema.parse(safe[key]));
  }
  if (table === "grinders") safe = grinderMutationSchema.parse(safe);
  return safe;
}
