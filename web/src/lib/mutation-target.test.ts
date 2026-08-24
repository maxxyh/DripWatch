import { describe, expect, it } from "vitest";
import { remoteDevelopmentWritesAllowed } from "./mutation-target";

describe("development mutation isolation", () => {
  it("blocks hosted databases by default in development", () => {
    expect(remoteDevelopmentWritesAllowed({
      NODE_ENV: "development",
      SUPABASE_URL: "https://production-project.supabase.co",
    })).toBe(false);
  });

  it("allows local Supabase and explicit remote opt-in", () => {
    expect(remoteDevelopmentWritesAllowed({
      NODE_ENV: "development",
      SUPABASE_URL: "http://127.0.0.1:54321",
    })).toBe(true);
    expect(remoteDevelopmentWritesAllowed({
      NODE_ENV: "development",
      SUPABASE_URL: "https://production-project.supabase.co",
      ALLOW_REMOTE_DEV_MUTATIONS: "1",
    })).toBe(true);
  });

  it("blocks local production mode and preview deployments", () => {
    expect(remoteDevelopmentWritesAllowed({
      NODE_ENV: "production",
      SUPABASE_URL: "https://production-project.supabase.co",
    })).toBe(false);
    expect(remoteDevelopmentWritesAllowed({
      NODE_ENV: "production",
      VERCEL_ENV: "preview",
      SUPABASE_URL: "https://production-project.supabase.co",
    })).toBe(false);
  });

  it("allows the deployed production environment", () => {
    expect(remoteDevelopmentWritesAllowed({
      NODE_ENV: "production",
      VERCEL_ENV: "production",
    })).toBe(true);
  });
});
