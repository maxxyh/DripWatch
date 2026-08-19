"use client";
import { useEffect, useRef, useState } from "react";
import { ChevronDown } from "lucide-react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import {
  Collapsible,
  CollapsibleContent,
  CollapsibleTrigger,
} from "@/components/ui/collapsible";
import {
  Field,
  FieldDescription,
  FieldGroup,
  FieldLabel,
} from "@/components/ui/field";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Toggle } from "@/components/ui/toggle";
import { ToggleGroup, ToggleGroupItem } from "@/components/ui/toggle-group";
import { NumericStepper } from "./numeric-stepper";
import { TimeInput } from "./time-input";
import type { GrinderRow, Recipe } from "@/lib/domain";
import {
  effectiveWater,
  reconcileWater,
  setTotalWater,
  suggestedTargets,
} from "@/lib/domain";
import { mutate } from "@/lib/client-mutations";
function reflowPours(recipe: Recipe, count = recipe.pourCount ?? 0): Recipe {
  if (count <= 0) return recipe;
  const targets = suggestedTargets(recipe, count);
  return {
    ...recipe,
    pourCount: count,
    pours: Array.from({ length: count }, (_, index) => ({
      ...recipe.pours[index],
      id: recipe.pours[index]?.id ?? crypto.randomUUID(),
      order: index + 1,
      toGrams: targets[index],
    })),
  };
}
export function RecipeEditor({
  recipe,
  onChange,
  method,
  grinders,
}: {
  recipe: Recipe;
  onChange: (r: Recipe) => void;
  method: "pourover" | "espresso";
  grinders: GrinderRow[];
}) {
  const [savedGrinders, setSavedGrinders] = useState<GrinderRow[]>([]);
  // Timings are off by default — reveal them only when there's already a schedule to follow, so
  // the form never invents times you'd have to delete.
  const [showTimes, setShowTimes] = useState(() =>
    recipe.pours.some((pour) => pour.startSec !== undefined || pour.endSec !== undefined),
  );
  const knownGrinders = [...savedGrinders, ...grinders].filter(
    (grinder, index, rows) =>
      rows.findIndex((candidate) => candidate.id === grinder.id) === index,
  );
  const grinderRows = useRef(knownGrinders);
  const pendingGrinderSaves = useRef(new Map<string, Promise<GrinderRow>>());
  const set = <K extends keyof Recipe>(key: K, value: Recipe[K]) =>
    onChange({ ...recipe, [key]: value });
  const selectedGrinder = knownGrinders.find(
    (grinder) => grinder.name === recipe.grinderName,
  );
  async function persistGrinder(rawName: string, stepless: boolean) {
    const name = rawName.trim();
    if (!name) return;
    const previous = pendingGrinderSaves.current.get(name);
    const operation = (previous ?? Promise.resolve(undefined)).then(
      async () => {
        const existing = grinderRows.current.find(
          (grinder) => grinder.name === name,
        );
        if (existing?.stepless === stepless) return existing;
        const now = new Date().toISOString();
        const saved = (await mutate(
          "grinders",
          existing
            ? { id: existing.id, stepless }
            : {
                id: crypto.randomUUID(),
                created_at: now,
                updated_at: now,
                deleted_at: null,
                name,
                stepless,
              },
          existing?.updated_at,
        )) as GrinderRow;
        grinderRows.current = [
          ...grinderRows.current.filter((grinder) => grinder.id !== saved.id),
          saved,
        ];
        setSavedGrinders((current) => [
          ...current.filter((grinder) => grinder.id !== saved.id),
          saved,
        ]);
        return saved;
      },
    );
    pendingGrinderSaves.current.set(name, operation);
    try {
      await operation;
    } catch (error) {
      toast.error(
        error instanceof Error ? error.message : "Could not save grinder",
      );
    } finally {
      if (pendingGrinderSaves.current.get(name) === operation)
        pendingGrinderSaves.current.delete(name);
    }
  }
  function setGrinderKind(stepless: boolean) {
    const name = recipe.grinderName?.trim();
    if (!name) return;
    onChange({
      ...recipe,
      grinderName: name,
      grindClickOffset: stepless ? 0 : recipe.grindClickOffset,
    });
    void persistGrinder(name, stepless);
  }
  useEffect(() => {
    if (
      method === "pourover" &&
      recipe.pourCount &&
      (recipe.pours.length !== recipe.pourCount ||
        (effectiveWater(recipe) !== undefined &&
          recipe.pours.every((pour) => pour.toGrams === undefined)))
    )
      onChange(reflowPours(recipe, recipe.pourCount));
  }, [method, onChange, recipe]);
  const changeDose = (value?: number) => {
    const next = reconcileWater({ ...recipe, doseGrams: value });
    onChange(reflowPours(next));
  };
  const changeCount = (value?: number) => {
    if (value === undefined) return onChange({ ...recipe, pourCount: undefined });
    onChange(reflowPours(recipe, Math.max(1, Math.min(12, value))));
  };
  return (
    <div className="flex flex-col gap-4">
      <Card>
        <CardHeader>
          <CardTitle>Recipe</CardTitle>
        </CardHeader>
        <CardContent>
          <FieldGroup>
            <div className="grid gap-4 sm:grid-cols-3">
              <Field className="sm:col-span-2">
                <FieldLabel htmlFor="grinder">Grinder</FieldLabel>
                <Input
                  id="grinder"
                  list="grinders"
                  value={recipe.grinderName ?? ""}
                  onChange={(e) => {
                    const name = e.target.value || undefined;
                    const grinder = knownGrinders.find(
                      (item) => item.name === name,
                    );
                    onChange({
                      ...recipe,
                      grinderName: name,
                      grindClickOffset: grinder?.stepless
                        ? 0
                        : recipe.grindClickOffset,
                    });
                  }}
                  onBlur={() => {
                    const name = recipe.grinderName?.trim();
                    if (name)
                      void persistGrinder(
                        name,
                        knownGrinders.find((item) => item.name === name)
                          ?.stepless ?? false,
                      );
                  }}
                  placeholder="1Zpresso J"
                />
                <datalist id="grinders">
                  {knownGrinders.map((g) => (
                    <option key={g.id}>{g.name}</option>
                  ))}
                </datalist>
              </Field>
              <Field>
                <FieldLabel htmlFor="dial">Dial</FieldLabel>
                <NumericStepper
                  id="dial"
                  step={0.1}
                  min={0}
                  max={60}
                  value={recipe.grindMajor}
                  onChange={(value) => set("grindMajor", value)}
                />
              </Field>
            </div>
            {recipe.grinderName?.trim() && (
              <Field>
                <FieldLabel>Grinder type</FieldLabel>
                <ToggleGroup
                  value={[selectedGrinder?.stepless ? "stepless" : "stepped"]}
                  onValueChange={(value) => {
                    if (value[0]) setGrinderKind(value[0] === "stepless");
                  }}
                >
                  <ToggleGroupItem value="stepped">Stepped</ToggleGroupItem>
                  <ToggleGroupItem value="stepless">Stepless</ToggleGroupItem>
                </ToggleGroup>
                <FieldDescription>
                  Stepless grinders use the absolute dial without a click
                  offset. New grinder names are saved for future recipes.
                </FieldDescription>
              </Field>
            )}
            <Field>
              <FieldLabel htmlFor="clicks">
                Clicks from dial (+ finer / − coarser)
              </FieldLabel>
              <NumericStepper
                id="clicks"
                min={-30}
                max={30}
                disabled={selectedGrinder?.stepless}
                value={recipe.grindClickOffset}
                onChange={(value) => set("grindClickOffset", value)}
              />
            </Field>
            <div className="grid grid-cols-2 gap-4">
              <Field>
                <FieldLabel htmlFor="dose">Dose (g)</FieldLabel>
                <NumericStepper
                  id="dose"
                  step={0.1}
                  min={0}
                  value={recipe.doseGrams}
                  onChange={changeDose}
                />
              </Field>
              {method === "pourover" ? (
                <>
                  <Field>
                    <FieldLabel htmlFor="temp">Water (°C)</FieldLabel>
                    <NumericStepper
                      id="temp"
                      min={0}
                      value={recipe.waterTempC}
                      onChange={(value) => set("waterTempC", value)}
                    />
                  </Field>
                  <Field>
                    <FieldLabel htmlFor="ratio">Ratio 1:</FieldLabel>
                    <NumericStepper
                      id="ratio"
                      step={0.1}
                      min={0}
                      value={recipe.ratio}
                      onChange={(value) =>
                        onChange(
                          reflowPours({
                            ...recipe,
                            ratio: value,
                          }),
                        )
                      }
                    />
                  </Field>
                  <Field>
                    <FieldLabel htmlFor="water">Total water (g)</FieldLabel>
                    <NumericStepper
                      id="water"
                      step={0.1}
                      min={0}
                      value={effectiveWater(recipe)}
                      onChange={(value) =>
                        onChange(
                          reflowPours(
                            setTotalWater(recipe, value),
                          ),
                        )
                      }
                    />
                  </Field>
                  <Field>
                    <FieldLabel htmlFor="pours">Pours</FieldLabel>
                    <NumericStepper
                      id="pours"
                      min={1}
                      max={12}
                      value={recipe.pourCount}
                      onChange={changeCount}
                    />
                  </Field>
                  <Field>
                    <FieldLabel htmlFor="bloom">Bloom</FieldLabel>
                    <TimeInput
                      id="bloom"
                      seconds={recipe.bloomTimeSec}
                      onChange={(value) => set("bloomTimeSec", value)}
                    />
                  </Field>
                  <Field>
                    <FieldLabel htmlFor="tdd">Drawdown (TDD)</FieldLabel>
                    <TimeInput
                      id="tdd"
                      seconds={recipe.totalDrawdownSec}
                      onChange={(value) => set("totalDrawdownSec", value)}
                    />
                  </Field>
                </>
              ) : (
                <>
                  <Field>
                    <FieldLabel htmlFor="espresso-temp">Water (°C)</FieldLabel>
                    <NumericStepper
                      id="espresso-temp"
                      min={0}
                      value={recipe.waterTempC}
                      onChange={(value) => set("waterTempC", value)}
                    />
                  </Field>
                  <Field>
                    <FieldLabel htmlFor="yield">Yield (g)</FieldLabel>
                    <NumericStepper
                      id="yield"
                      step={0.1}
                      min={0}
                      value={recipe.yieldGrams}
                      onChange={(value) => set("yieldGrams", value)}
                    />
                  </Field>
                </>
              )}
            </div>
          </FieldGroup>
        </CardContent>
      </Card>
      {method === "pourover" && recipe.pours.length > 0 && (
        <Collapsible defaultOpen={false}>
          <Card>
            <CardHeader>
              <CollapsibleTrigger
                render={
                  <Button variant="ghost" className="w-full justify-between" />
                }
              >
                Pour breakdown
                <ChevronDown data-icon="inline-end" />
              </CollapsibleTrigger>
              <CardDescription>
                The last pour always matches total water.
              </CardDescription>
            </CardHeader>
            <CollapsibleContent>
              <CardContent>
                <FieldGroup>
                  <Toggle
                    variant="outline"
                    size="sm"
                    className="self-start"
                    pressed={showTimes}
                    onPressedChange={setShowTimes}
                  >
                    Add pour timings
                  </Toggle>
                  {recipe.pours.map((pour, i) => {
                    const setGrams = (grams?: number) => {
                      const pours = [...recipe.pours],
                        nextPour = { ...pour, toGrams: grams };
                      pours[i] = nextPour;
                      onChange(
                        i === pours.length - 1 && grams !== undefined
                          ? reflowPours(
                              setTotalWater({ ...recipe, pours }, grams),
                            )
                          : { ...recipe, pours },
                      );
                    };
                    return (
                      <div
                        key={pour.id}
                        className={
                          showTimes
                            ? "grid grid-cols-[2rem_1fr_4rem_4rem] items-end gap-2"
                            : "flex items-end gap-2"
                        }
                      >
                        <strong className="pb-2 font-mono text-primary">
                          {i + 1}
                        </strong>
                        {/* A plain compact field, not the +/- StepperCluster used for the
                            always-visible fields above: three of those side by side can't fit a
                            phone's width, so per-pour rows use narrow typed fields instead — the
                            same tradeoff the native app makes for this exact row. */}
                        <Field className={showTimes ? "" : "flex-1"}>
                          <FieldLabel htmlFor={`pour-${i}`}>To grams</FieldLabel>
                          <Input
                            id={`pour-${i}`}
                            type="text"
                            inputMode="decimal"
                            className="text-center font-mono tabular-nums"
                            value={pour.toGrams ?? ""}
                            onChange={(event) => {
                              const raw = event.target.value.replace(",", ".");
                              if (!/^\d*\.?\d*$/.test(raw)) return;
                              // A bare "." matches the pattern above but parses to NaN — treat
                              // it (and any other non-finite mid-typing state) as "keep waiting
                              // for more digits" rather than committing it to recipe state.
                              const parsed = raw === "" ? undefined : Number(raw);
                              if (parsed !== undefined && !Number.isFinite(parsed))
                                return;
                              setGrams(parsed);
                            }}
                          />
                        </Field>
                        {showTimes && (
                          <>
                            <Field>
                              <FieldLabel htmlFor={`start-${i}`}>
                                Start
                              </FieldLabel>
                              <TimeInput
                                id={`start-${i}`}
                                seconds={pour.startSec}
                                onChange={(value) => {
                                  const pours = [...recipe.pours];
                                  pours[i] = { ...pour, startSec: value };
                                  onChange({ ...recipe, pours });
                                }}
                              />
                            </Field>
                            <Field>
                              <FieldLabel htmlFor={`end-${i}`}>End</FieldLabel>
                              <TimeInput
                                id={`end-${i}`}
                                seconds={pour.endSec}
                                onChange={(value) => {
                                  const pours = [...recipe.pours];
                                  pours[i] = { ...pour, endSec: value };
                                  onChange({ ...recipe, pours });
                                }}
                              />
                            </Field>
                            <Field className="col-start-2 col-span-3">
                              <FieldLabel htmlFor={`style-${i}`}>
                                Pour style
                              </FieldLabel>
                              <Input
                                id={`style-${i}`}
                                value={pour.style ?? ""}
                                onChange={(event) => {
                                  const pours = [...recipe.pours];
                                  pours[i] = {
                                    ...pour,
                                    style: event.target.value || undefined,
                                  };
                                  onChange({ ...recipe, pours });
                                }}
                              />
                            </Field>
                          </>
                        )}
                      </div>
                    );
                  })}
                </FieldGroup>
              </CardContent>
            </CollapsibleContent>
          </Card>
        </Collapsible>
      )}
      <Collapsible>
        <Card>
          <CardHeader>
            <CollapsibleTrigger
              render={
                <Button variant="ghost" className="w-full justify-between" />
              }
            >
              Specialist detail
              <ChevronDown data-icon="inline-end" />
            </CollapsibleTrigger>
          </CardHeader>
          <CollapsibleContent>
            <CardContent>
              <FieldGroup>
                {method === "espresso" && (
                  <div className="grid grid-cols-3 gap-3">
                    <Field>
                      <FieldLabel htmlFor="pre">Pre-infuse</FieldLabel>
                      <NumericStepper
                        id="pre"
                        min={0}
                        value={recipe.preInfusionSec}
                        onChange={(value) => set("preInfusionSec", value)}
                      />
                    </Field>
                    <Field>
                      <FieldLabel htmlFor="surf">Surf wait</FieldLabel>
                      <NumericStepper
                        id="surf"
                        min={0}
                        value={recipe.surfWaitSec}
                        onChange={(value) => set("surfWaitSec", value)}
                      />
                    </Field>
                    <Field>
                      <FieldLabel htmlFor="steam">Steam mode</FieldLabel>
                      <NumericStepper
                        id="steam"
                        min={0}
                        value={recipe.steamModeSec}
                        onChange={(value) => set("steamModeSec", value)}
                      />
                    </Field>
                  </div>
                )}
                <Field>
                  <FieldLabel htmlFor="recipe-notes">
                    Technique notes
                  </FieldLabel>
                  <Textarea
                    id="recipe-notes"
                    value={recipe.notes ?? ""}
                    onChange={(e) => set("notes", e.target.value || undefined)}
                  />
                  <FieldDescription>
                    Agitation, pour height, temperature surf, or anything else
                    worth reproducing.
                  </FieldDescription>
                </Field>
              </FieldGroup>
            </CardContent>
          </CollapsibleContent>
        </Card>
      </Collapsible>
    </div>
  );
}
