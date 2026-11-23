import { describe, expect, it } from "vitest";
import { safeNextPath } from "./safe-next";

describe("safeNextPath", () => {
  it("keeps valid relative app paths and query strings", () => {
    expect(safeNextPath("/")).toBe("/");
    expect(safeNextPath("/beans/123")).toBe("/beans/123");
    expect(safeNextPath("/beans/123/brews/new?method=espresso")).toBe(
      "/beans/123/brews/new?method=espresso",
    );
    expect(safeNextPath(["/beans/123", "/beans/456"])).toBe("/beans/123");
  });

  it("falls back to / for missing, external, or backslash-redirect inputs", () => {
    expect(safeNextPath(undefined)).toBe("/");
    expect(safeNextPath(null)).toBe("/");
    expect(safeNextPath("")).toBe("/");
    expect(safeNextPath("https://evil.example/beans")).toBe("/");
    expect(safeNextPath("//evil.example/beans")).toBe("/");
    expect(safeNextPath("/\\evil.example/beans")).toBe("/");
    expect(safeNextPath("/beans\r\nSet-Cookie: a=b")).toBe("/");
  });

  it("prevents redirecting back to /login", () => {
    expect(safeNextPath("/login")).toBe("/");
    expect(safeNextPath("/login?next=/beans/123")).toBe("/");
    expect(safeNextPath("/login/extra")).toBe("/");
  });
});
