import { describe, expect, it } from "vitest";
import {
  asPlanSeed,
  brewDiff,
  brewHistoryMarkdown,
  brewMarkdown,
  canonicalizePourTimings,
  effectiveWater,
  grindDisplay,
  grinderIdentityKey,
  dedupeGrinders,
  hasTaste,
  newPourover,
  normalizeTerm,
  normalizeTerms,
  pourFlowRateGramsPerSecond,
  pricePerGramSGD,
  pricePerGramTextSGD,
  reconcileWater,
  liveTimeEntry,
  secondsFromDigits,
  singlePendingPlanPatch,
  setTotalWater,
  setBloomTime,
  suggestedTargets,
  type BeanRow,
  type BrewRow,
  type Recipe,
} from "./domain";
import { grinderMutationSchema, recipeSchema, tasteSchema } from "./domain-schema";
describe("Swift recipe parity", () => {
  it("uses brew start and bloom as the first two canonical pour starts", () => {
    const recipe: Recipe = {
      pours: [
        { id: crypto.randomUUID(), order: 1, startSec: 12 },
        { id: crypto.randomUUID(), order: 2, startSec: 60 },
        { id: crypto.randomUUID(), order: 3, startSec: 90 },
      ],
      bloomTimeSec: 45,
    };

    expect(canonicalizePourTimings(recipe).pours.map((pour) => pour.startSec)).toEqual([
      0, 45, 90,
    ]);
  });

  it("updates the second pour start when bloom changes", () => {
    const recipe: Recipe = {
      pours: [
        { id: crypto.randomUUID(), order: 1 },
        { id: crypto.randomUUID(), order: 2 },
        { id: crypto.randomUUID(), order: 3, startSec: 90 },
      ],
    };

    expect(setBloomTime(recipe, 40)).toMatchObject({
      bloomTimeSec: 40,
      pours: [{ startSec: 0 }, { startSec: 40 }, { startSec: 90 }],
    });
  });

  it("promotes a legacy second pour start when bloom is missing", () => {
    const recipe: Recipe = {
      pours: [
        { id: crypto.randomUUID(), order: 1 },
        { id: crypto.randomUUID(), order: 2, startSec: 45 },
      ],
    };

    expect(canonicalizePourTimings(recipe)).toMatchObject({
      bloomTimeSec: 45,
      pours: [{ startSec: 0 }, { startSec: 45 }],
    });
  });

  it("clears the second pour start when bloom is explicitly cleared", () => {
    const recipe: Recipe = {
      bloomTimeSec: 45,
      pours: [
        { id: crypto.randomUUID(), order: 1, startSec: 0 },
        { id: crypto.randomUUID(), order: 2, startSec: 45 },
      ],
    };

    expect(setBloomTime(recipe, undefined)).toMatchObject({
      bloomTimeSec: undefined,
      pours: [{ startSec: 0 }, { startSec: undefined }],
    });
  });

  it("starts a pourover with native defaults", () =>
    expect(newPourover()).toMatchObject({
      waterTempC: 92,
      bloomTimeSec: 30,
      ratio: 15,
      pourCount: 3,
      pours: [],
    }));
  it("reconciles exact total water through ratio", () => {
    let r: Recipe = { pours: [], doseGrams: 15 };
    r = setTotalWater(r, 220);
    expect(effectiveWater(r)).toBeCloseTo(220);
    expect(r.totalWaterGrams).toBeUndefined();
  });
  it("folds a total entered before dose", () => {
    let r = setTotalWater({ pours: [] }, 240);
    r = reconcileWater({ ...r, doseGrams: 15 });
    expect(r).toMatchObject({ doseGrams: 15, ratio: 16 });
    expect(r.totalWaterGrams).toBeUndefined();
  });
  it("suggests bloom-aware cumulative targets and preserves exact total", () => {
    expect(
      suggestedTargets({ pours: [], doseGrams: 15, ratio: 16 }, 4),
    ).toEqual([45, 110, 175, 240]);
    const t = suggestedTargets(
      setTotalWater({ pours: [], doseGrams: 15 }, 223),
      4,
    );
    expect(t.at(-1)).toBeCloseTo(223);
  });
  it("drops measured outcomes from a plan seed", () =>
    expect(
      asPlanSeed({
        pours: [],
        shotTimeSec: 28,
        totalDrawdownSec: 135,
        doseGrams: 18,
      }),
    ).toEqual({
      pours: [],
      shotTimeSec: undefined,
      totalDrawdownSec: undefined,
      doseGrams: 18,
    }));
});

describe("hasTaste", () => {
  it("treats the untouched taste shape as empty", () => {
    expect(hasTaste({ positives: [], negatives: [], balance: {} })).toBe(false);
  });

  it("recognizes each persisted kind of tasting input", () => {
    expect(
      hasTaste({ positives: ["Sweet"], negatives: [], balance: {} }),
    ).toBe(true);
    expect(
      hasTaste({ positives: [], negatives: ["Dry"], balance: {} }),
    ).toBe(true);
    expect(
      hasTaste({ positives: [], negatives: [], balance: { body: 3 } }),
    ).toBe(true);
    expect(
      hasTaste({ positives: [], negatives: [], balance: {}, rating: 4 }),
    ).toBe(true);
    expect(
      hasTaste({ positives: [], negatives: [], balance: {}, note: "Juicy" }),
    ).toBe(true);
    expect(
      hasTaste({ positives: [], negatives: [], balance: {}, note: "   " }),
    ).toBe(false);
  });
});
describe("instrument formatting and diffs", () => {
  it("deduplicates grinder identity without changing display casing", () => {
    const first = {
      id: crypto.randomUUID(),
      created_at: "2026-01-01T00:00:00.000Z",
      updated_at: "2026-01-01T00:00:00.000Z",
      deleted_at: null,
      name: "1Zpresso J",
      stepless: false,
    };
    const duplicate = {
      ...first,
      id: crypto.randomUUID(),
      created_at: "2026-02-01T00:00:00.000Z",
      name: "1ZPresso J",
    };

    expect(grinderIdentityKey(" 1ZPresso J ")).toBe("1zpresso j");
    expect(dedupeGrinders([duplicate, first])).toEqual([first]);
  });
  it("shows absolute signed grind", () =>
    expect(
      grindDisplay({ grinderName: "1Zpresso J", major: 3, clickOffset: -1 }),
    ).toBe("1Zpresso J · 3(−1)"));
  it("only asserts click direction on the same grinder dial", () => {
    expect(
      brewDiff(
        { pours: [], grinderName: "J", grindMajor: 3, grindClickOffset: 0 },
        { pours: [], grinderName: "J", grindMajor: 3, grindClickOffset: -1 },
      ),
    ).toContain("1 click coarser");
    expect(
      brewDiff(
        { pours: [], grinderName: "J", grindMajor: 3, grindClickOffset: 0 },
        { pours: [], grinderName: "J", grindMajor: 2, grindClickOffset: 0 },
      )[0],
    ).toBe("grind 3 → 2");
  });

  it("round-trips a pourover dripper and reports a changed dripper", () => {
    const recipe = recipeSchema.parse({
      dripperName: "V60 Neo",
      pours: [],
    });
    expect(recipe.dripperName).toBe("V60 Neo");
    expect(recipeSchema.parse({ dripperName: "   ", pours: [] }).dripperName).toBeUndefined();
    expect(
      brewDiff(
        { dripperName: "Hario V60 (Ceramic)", pours: [] },
        { dripperName: "V60 Neo", pours: [] },
      ),
    ).toContain("dripper → V60 Neo");
    expect(brewDiff({ pours: [] }, { dripperName: "V60 Neo", pours: [] }))
      .toContain("dripper → V60 Neo");
    expect(brewDiff({ dripperName: "V60 Neo", pours: [] }, { pours: [] }))
      .toContain("dripper cleared");
  });
  it("normalizes and deduplicates taste terms", () =>
    expect(normalizeTerms([" honey ", "HONEY", "red plum", "RED TEA"])).toEqual(
      ["Honey", "Red Plum", "RED TEA"],
    ));
  it("matches native normalization for digit codes and four-letter acronyms", () => {
    expect(normalizeTerm("  usda   tha1 sl-34 pink BOURBON  ")).toBe(
      "Usda tha1 Sl-34 Pink Bourbon",
    );
    expect(normalizeTerm("USDA THA1 SL-34 pink bourbon")).toBe(
      "USDA THA1 SL-34 Pink Bourbon",
    );
    expect(normalizeTerms([" USDA ", "usda", "", "THA1", "tha1"])).toEqual([
      "USDA",
      "THA1",
    ]);
  });
  it("computes a pour's flow rate from its water delta and time window", () => {
    // 60g over a 0:00–0:30 bloom is 2g/s.
    expect(pourFlowRateGramsPerSecond(0, 60, 0, 30)).toBe(2);
    // A later pour's delta is against the *previous* cumulative target, not its own total.
    expect(pourFlowRateGramsPerSecond(60, 160, 30, 50)).toBe(5);
  });
  it("leaves flow rate undefined without complete or sensible timing", () => {
    expect(pourFlowRateGramsPerSecond(0, 60, undefined, 30)).toBeUndefined();
    expect(pourFlowRateGramsPerSecond(0, undefined, 0, 30)).toBeUndefined();
    expect(pourFlowRateGramsPerSecond(0, 60, 30, 30)).toBeUndefined(); // zero-length window
    expect(pourFlowRateGramsPerSecond(60, 60, 0, 30)).toBeUndefined(); // no water delta
    expect(pourFlowRateGramsPerSecond(60, 40, 0, 30)).toBeUndefined(); // negative delta
    // A later pour whose *previous* row hasn't had its water target typed in yet must not be
    // silently treated as zero — that would show an inflated, made-up rate.
    expect(pourFlowRateGramsPerSecond(undefined, 160, 30, 50)).toBeUndefined();
  });
});
describe("brew markdown export", () => {
  const bean: BeanRow = {
    id: crypto.randomUUID(),
    created_at: "2026-01-01T00:00:00.000Z",
    updated_at: "2026-01-01T00:00:00.000Z",
    deleted_at: null,
    name: "Voyager",
    roaster_name: "Voyager Craft",
    country: null,
    region: null,
    farm: null,
    varietal: null,
    process: null,
    roast_level: null,
    roast_date: null,
    roaster_notes: null,
    price_sgd: null,
    bag_size_grams: null,
    my_flavor_tags: [],
    finished_at: null,
    pending_next_pourover: null,
    pending_next_espresso: null,
  };
  const baseRecipe: Recipe = {
    pours: [],
    grinderName: "1Zpresso J",
    grindMajor: 3,
    grindClickOffset: -1,
    waterTempC: 92,
    doseGrams: 15,
    ratio: 16,
  };
  function makeBrew(overrides: Partial<BrewRow>): BrewRow {
    return {
      id: crypto.randomUUID(),
      created_at: "2026-01-01T00:00:00.000Z",
      updated_at: "2026-01-01T00:00:00.000Z",
      deleted_at: null,
      brewed_at: "2026-01-01T00:00:00.000Z",
      method_raw: "pourover",
      brewers: [],
      recipe: baseRecipe,
      taste: { positives: [], negatives: [], balance: {} },
      next_recipe_draft: null,
      photo_path: null,
      bean_id: bean.id,
      ...overrides,
    };
  }
  it("writes the full recipe once then only what changed per later brew", () => {
    const brew1 = makeBrew({
      brewed_at: "2026-01-01T00:00:00.000Z",
      taste: { positives: ["honey"], negatives: [], balance: {} },
    });
    const brew2 = makeBrew({
      brewed_at: "2026-01-02T00:00:00.000Z",
      recipe: { ...baseRecipe, grindClickOffset: 1 }, // 2 clicks finer
      taste: { positives: [], negatives: ["sour"], balance: {} },
    });

    // Passed newest-first, like the app's own brew lists.
    const md = brewHistoryMarkdown(bean, [brew2, brew1]);

    expect(md).toContain("Brew history (2 brews)");
    expect(md).toContain("## Brew 1");
    expect(md).toContain("**Recipe**");
    expect(md).toContain("1Zpresso J · 3(−1)");
    expect(md).toContain("## Brew 2");
    expect(md).toContain("**Changes:**");
    expect(md).toContain("2 clicks finer");
    expect(md).toContain("Good: honey");
    expect(md).toContain("Off: sour");
    // Unchanged fields (temp, dose, ratio) aren't repeated as a second full recipe block.
    expect(md.split("**Recipe**").length - 1).toBe(1);
  });
  it("shows each pour's flow rate in the pour-by-pour breakdown", () => {
    const brew = makeBrew({
      recipe: {
        ...baseRecipe,
        pourCount: 2,
        bloomTimeSec: 30,
        pours: [
          { id: crypto.randomUUID(), order: 1, toGrams: 60, endSec: 30 },
          {
            id: crypto.randomUUID(),
            order: 2,
            toGrams: 240,
            startSec: 30,
            endSec: 60,
          },
        ],
      },
    });

    const md = brewMarkdown(bean, brew);

    expect(md).toContain("Pour-by-pour");
    expect(md).toContain("#1: 0:00–0:30 → 60 g · 2 g/s");
    expect(md).toContain("#2: 0:30–1:00 → 240 g · 6 g/s");
  });
});
describe("native input behavior", () => {
  it("derives SGD per gram only from positive complete purchase values", () => {
    expect(pricePerGramSGD(36.5, 250)).toBeCloseTo(0.146);
    expect(pricePerGramSGD(null, 250)).toBeNull();
    expect(pricePerGramSGD(36.5, null)).toBeNull();
    expect(pricePerGramSGD(0, 250)).toBeNull();
    expect(pricePerGramSGD(Number.MAX_VALUE, Number.MIN_VALUE)).toBeNull();
    expect(pricePerGramTextSGD(0.146)).toBe("S$0.15/g");
    expect(pricePerGramTextSGD(1_250, "en-SG")).toBe("S$1.25K/g");
  });
  it("treats the last two digits as seconds", () => {
    expect(secondsFromDigits("45")).toBe(45);
    expect(secondsFromDigits("230")).toBe(150);
    expect(secondsFromDigits("12:30")).toBe(750);
    expect(secondsFromDigits("")).toBeUndefined();
  });
  it("formats time entry live and caps it at four digits", () => {
    expect(liveTimeEntry("00210")).toEqual({ text: "2:10", seconds: 130 });
    expect(liveTimeEntry("12345")).toEqual({ text: "12:34", seconds: 754 });
  });
  it("keeps exactly one bean-level pending plan", () => {
    const draft: Recipe = { pours: [], doseGrams: 20 };
    expect(singlePendingPlanPatch("pourover", draft)).toEqual({
      pending_next_pourover: draft,
      pending_next_espresso: null,
    });
    expect(singlePendingPlanPatch("espresso", null)).toEqual({
      pending_next_pourover: null,
      pending_next_espresso: null,
    });
  });
});
describe("Swift JSON contracts", () => {
  it("accepts representative camelCase recipe and required pour UUID", () =>
    expect(
      recipeSchema.parse({
        grinderName: "J",
        grindMajor: 3,
        grindClickOffset: -1,
        waterTempC: 92,
        pours: [
          { id: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa", order: 1, toGrams: 45 },
        ],
      }).pours,
    ).toHaveLength(1));
  it("requires taste arrays and balance", () => {
    expect(() => tasteSchema.parse({ balance: {} })).toThrow();
    expect(
      tasteSchema.parse({ positives: [], negatives: [], balance: {} }),
    ).toBeTruthy();
  });
  it("accepts safe grinder inserts and partial updates", () => {
    const id = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa";
    expect(
      grinderMutationSchema.parse({ id, name: "DF54", stepless: true }),
    ).toEqual({ id, name: "DF54", stepless: true });
    expect(grinderMutationSchema.parse({ id, stepless: false })).toEqual({
      id,
      stepless: false,
    });
    expect(() =>
      grinderMutationSchema.parse({ id, stepless: "yes" }),
    ).toThrow();
  });
});
