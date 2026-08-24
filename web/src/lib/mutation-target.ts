const localHosts = new Set(["localhost", "127.0.0.1", "::1"]);

/// Local UI verification is read-only against hosted data by default. Developers must point at
/// local Supabase or make an explicit choice before a dev server can mutate a remote database.
export function remoteDevelopmentWritesAllowed(env: NodeJS.ProcessEnv = process.env) {
  if (env.ALLOW_REMOTE_DEV_MUTATIONS === "1") return true;
  if (env.NODE_ENV === "production" && env.VERCEL_ENV === "production") return true;
  try {
    return localHosts.has(new URL(env.SUPABASE_URL ?? "").hostname);
  } catch {
    return false;
  }
}

export function requireSafeMutationTarget() {
  if (!remoteDevelopmentWritesAllowed())
    throw new Error("REMOTE_DEV_WRITES_DISABLED");
}
