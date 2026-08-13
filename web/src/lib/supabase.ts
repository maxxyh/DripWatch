import "server-only";
import { createClient } from "@supabase/supabase-js";
import type { Database } from "./database.types";
export function supabase() {
  const url = process.env.SUPABASE_URL,
    key = process.env.SUPABASE_ANON_KEY;
  if (!url || !key)
    throw new Error("Supabase is not configured. See web/.env.example.");
  return createClient<Database>(url, key, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}
