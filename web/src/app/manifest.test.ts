import { describe, expect, it } from "vitest";
import manifest from "./manifest";
describe("PWA manifest", () => {
  it("is installable and includes maskable icon", () => {
    const value = manifest();
    expect(value.display).toBe("standalone");
    expect(value.start_url).toBe("/");
    expect(value.icons?.some((x) => x.purpose === "maskable")).toBe(true);
  });
});
