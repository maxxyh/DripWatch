import { describe, expect, it } from "vitest";
import {
  asPlanSeed,
  brewDiff,
  effectiveWater,
  grindDisplay,
  hasTaste,
  newPourover,
  normalizeTerm,
  normalizeTerms,
  pricePerGramSGD,
  pricePerGramTextSGD,
  reconcileWater,
  liveTimeEntry,
  secondsFromDigits,
  singlePendingPlanPatch,
  setTotalWater,
  suggestedTargets,
  type Recipe,
} from "./domain";
import { grinderMutationSchema, recipeSchema, tasteSchema } from "./domain-schema";
describe("Swift recipe parity", () => {
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
