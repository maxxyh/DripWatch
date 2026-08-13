import sharp from "sharp";
import { describe, expect, it } from "vitest";
import { validateNormalizedJpeg } from "./photo-validation";

describe("normalized photo validation", () => {
  it("accepts a bounded JPEG", async () => {
    const image = await sharp({
      create: { width: 1400, height: 800, channels: 3, background: "white" },
    })
      .jpeg()
      .toBuffer();
    await expect(validateNormalizedJpeg(image)).resolves.toBe(true);
  });

  it("rejects oversized, corrupt, and non-JPEG input", async () => {
    const oversized = await sharp({
      create: { width: 1401, height: 10, channels: 3, background: "white" },
    })
      .jpeg()
      .toBuffer();
    const png = await sharp({
      create: { width: 10, height: 10, channels: 3, background: "white" },
    })
      .png()
      .toBuffer();
    await expect(validateNormalizedJpeg(oversized)).resolves.toBe(false);
    await expect(validateNormalizedJpeg(png)).resolves.toBe(false);
    await expect(
      validateNormalizedJpeg(new Uint8Array([0xff, 0xd8, 0xff])),
    ).resolves.toBe(false);
  });
});
