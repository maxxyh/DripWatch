import { readFile } from "node:fs/promises";
import { describe, expect, it } from "vitest";

describe("protected photo cache contract", () => {
  it("bounds photos by count and bytes and isolates session scopes", async () => {
    const source = await readFile("public/sw.js", "utf8");
    expect(source).toContain("MAX_PROTECTED_PHOTOS = 120");
    expect(source).toContain("MAX_PROTECTED_PHOTO_BYTES = 100 * 1024 * 1024");
    expect(source).toContain('headers.set("X-DripWatch-Bytes"');
    expect(source).toContain("await pruneProtectedPhotos(cache)");
    expect(source).toContain("key !== protectedCache(lease.cacheScope)");
  });

  it("keeps caching best-effort after a successful network response", async () => {
    const source = await readFile("public/sw.js", "utf8");
    expect(source).toContain(
      "Offline caching is best-effort; never mask a valid network response.",
    );
  });
});
