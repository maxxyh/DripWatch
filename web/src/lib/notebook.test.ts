import { describe, expect, it } from "vitest";
import { safeMutation } from "./notebook-mutation";

const legacyRecipe = () => ({
  pours: [
    { id: crypto.randomUUID(), order: 1, startSec: 12 },
    { id: crypto.randomUUID(), order: 2, startSec: 45 },
  ],
});

describe("notebook mutation boundary", () => {
  it("canonicalizes brew recipes before writing them", () => {
    const safe = safeMutation("brews", {
      id: crypto.randomUUID(),
      recipe: legacyRecipe(),
      next_recipe_draft: legacyRecipe(),
    });

    expect(safe.recipe).toMatchObject({
      bloomTimeSec: 45,
      pours: [{ startSec: 0 }, { startSec: 45 }],
    });
    expect(safe.next_recipe_draft).toMatchObject({
      bloomTimeSec: 45,
      pours: [{ startSec: 0 }, { startSec: 45 }],
    });
  });

  it("canonicalizes pending bean recipes before writing them", () => {
    const safe = safeMutation("beans", {
      id: crypto.randomUUID(),
      pending_next_pourover: legacyRecipe(),
    });

    expect(safe.pending_next_pourover).toMatchObject({
      bloomTimeSec: 45,
      pours: [{ startSec: 0 }, { startSec: 45 }],
    });
  });
});
