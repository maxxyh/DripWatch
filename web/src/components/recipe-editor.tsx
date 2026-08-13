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
import { ToggleGroup, ToggleGroupItem } from "@/components/ui/toggle-group";
import type { GrinderRow, Recipe } from "@/lib/domain";
import {
  effectiveWater,
  reconcileWater,
  setTotalWater,
  suggestedTargets,
} from "@/lib/domain";
import { mutate } from "@/lib/client-mutations";
const number = (value: string) => (value === "" ? undefined : Number(value));
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
  const changeDose = (v: string) => {
    const next = reconcileWater({ ...recipe, doseGrams: number(v) });
    onChange(reflowPours(next));
  };
  const changeCount = (v: string) => {
    const count = Math.max(1, Math.min(12, Number(v) || 1));
    onChange(reflowPours(recipe, count));
  };
  return (
    <div className="flex flex-col gap-4">
      <Card>
        <CardHeader>
          <CardTitle>Everyday recipe</CardTitle>
          <CardDescription>
            Keep the absolute recipe visible; open specialist detail only when
            needed.
          </CardDescription>
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
                <Input
                  id="dial"
                  type="number"
                  step="0.1"
                  value={recipe.grindMajor ?? ""}
                  onChange={(e) => set("grindMajor", number(e.target.value))}
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
              <Input
                id="clicks"
                type="number"
                min="-30"
                max="30"
                disabled={selectedGrinder?.stepless}
                value={recipe.grindClickOffset ?? 0}
                onChange={(e) =>
                  set("grindClickOffset", Number(e.target.value))
                }
              />
            </Field>
            <div className="grid grid-cols-2 gap-4">
              <Field>
                <FieldLabel htmlFor="dose">Dose (g)</FieldLabel>
                <Input
                  id="dose"
                  inputMode="decimal"
                  type="number"
                  step="0.1"
                  value={recipe.doseGrams ?? ""}
                  onChange={(e) => changeDose(e.target.value)}
                />
              </Field>
              {method === "pourover" ? (
                <>
                  <Field>
                    <FieldLabel htmlFor="temp">Water (°C)</FieldLabel>
                    <Input
                      id="temp"
                      inputMode="numeric"
                      type="number"
                      value={recipe.waterTempC ?? ""}
                      onChange={(e) =>
                        set("waterTempC", number(e.target.value))
                      }
                    />
                  </Field>
                  <Field>
                    <FieldLabel htmlFor="ratio">Ratio 1:</FieldLabel>
                    <Input
                      id="ratio"
                      inputMode="decimal"
                      type="number"
                      step="0.1"
                      value={recipe.ratio ?? ""}
                      onChange={(e) =>
                        onChange(
                          reflowPours({
                            ...recipe,
                            ratio: number(e.target.value),
                          }),
                        )
                      }
                    />
                  </Field>
                  <Field>
                    <FieldLabel htmlFor="water">Total water (g)</FieldLabel>
                    <Input
                      id="water"
                      inputMode="decimal"
                      type="number"
                      step="0.1"
                      value={effectiveWater(recipe) ?? ""}
                      onChange={(e) =>
                        onChange(
                          reflowPours(
                            setTotalWater(recipe, number(e.target.value)),
                          ),
                        )
                      }
                    />
                  </Field>
                  <Field>
                    <FieldLabel htmlFor="pours">Pours</FieldLabel>
                    <Input
                      id="pours"
                      type="number"
                      min="1"
                      max="12"
                      value={recipe.pourCount ?? ""}
                      onChange={(e) => changeCount(e.target.value)}
                    />
                  </Field>
                  <Field>
                    <FieldLabel htmlFor="bloom">Bloom (sec)</FieldLabel>
                    <Input
                      id="bloom"
                      type="number"
                      value={recipe.bloomTimeSec ?? ""}
                      onChange={(e) =>
                        set("bloomTimeSec", number(e.target.value))
                      }
                    />
                  </Field>
                </>
              ) : (
                <>
                  <Field>
                    <FieldLabel htmlFor="espresso-temp">Water (°C)</FieldLabel>
                    <Input
                      id="espresso-temp"
                      type="number"
                      value={recipe.waterTempC ?? ""}
                      onChange={(event) =>
                        set("waterTempC", number(event.target.value))
                      }
                    />
                  </Field>
                  <Field>
                    <FieldLabel htmlFor="yield">Yield (g)</FieldLabel>
                    <Input
                      id="yield"
                      type="number"
                      step="0.1"
                      value={recipe.yieldGrams ?? ""}
                      onChange={(e) =>
                        set("yieldGrams", number(e.target.value))
                      }
                    />
                  </Field>
                </>
              )}
            </div>
          </FieldGroup>
        </CardContent>
      </Card>
      {method === "pourover" && recipe.pours.length > 0 && (
        <Card>
          <CardHeader>
            <CardTitle>Pour rail</CardTitle>
            <CardDescription>
              Cumulative scale targets. The final stop is the exact total water.
            </CardDescription>
          </CardHeader>
          <CardContent>
            <FieldGroup>
              {recipe.pours.map((pour, i) => (
                <div
                  key={pour.id}
                  className="grid grid-cols-[2rem_1fr_1fr] items-end gap-2"
                >
                  <strong className="pb-2 font-mono text-primary">
                    {i + 1}
                  </strong>
                  <Field>
                    <FieldLabel htmlFor={`pour-${i}`}>To grams</FieldLabel>
                    <Input
                      id={`pour-${i}`}
                      type="number"
                      step="0.1"
                      value={pour.toGrams ?? ""}
                      onChange={(e) => {
                        const pours = [...recipe.pours],
                          grams = number(e.target.value);
                        pours[i] = { ...pour, toGrams: grams };
                        onChange(
                          i === pours.length - 1
                            ? reflowPours(
                                setTotalWater({ ...recipe, pours }, grams),
                              )
                            : { ...recipe, pours },
                        );
                      }}
                    />
                  </Field>
                  <Field>
                    <FieldLabel htmlFor={`start-${i}`}>Start sec</FieldLabel>
                    <Input
                      id={`start-${i}`}
                      type="number"
                      value={pour.startSec ?? ""}
                      onChange={(e) => {
                        const pours = [...recipe.pours];
                        pours[i] = {
                          ...pour,
                          startSec: number(e.target.value),
                        };
                        onChange({ ...recipe, pours });
                      }}
                    />
                  </Field>
                  <Field>
                    <FieldLabel htmlFor={`end-${i}`}>End sec</FieldLabel>
                    <Input
                      id={`end-${i}`}
                      type="number"
                      value={pour.endSec ?? ""}
                      onChange={(event) => {
                        const pours = [...recipe.pours];
                        pours[i] = {
                          ...pour,
                          endSec: number(event.target.value),
                        };
                        onChange({ ...recipe, pours });
                      }}
                    />
                  </Field>
                  <Field className="col-start-2 col-span-2">
                    <FieldLabel htmlFor={`style-${i}`}>Pour style</FieldLabel>
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
                </div>
              ))}
            </FieldGroup>
          </CardContent>
        </Card>
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
                      <Input
                        id="pre"
                        type="number"
                        value={recipe.preInfusionSec ?? ""}
                        onChange={(e) =>
                          set("preInfusionSec", number(e.target.value))
                        }
                      />
                    </Field>
                    <Field>
                      <FieldLabel htmlFor="surf">Surf wait</FieldLabel>
                      <Input
                        id="surf"
                        type="number"
                        value={recipe.surfWaitSec ?? ""}
                        onChange={(e) =>
                          set("surfWaitSec", number(e.target.value))
                        }
                      />
                    </Field>
                    <Field>
                      <FieldLabel htmlFor="steam">Steam mode</FieldLabel>
                      <Input
                        id="steam"
                        type="number"
                        value={recipe.steamModeSec ?? ""}
                        onChange={(e) =>
                          set("steamModeSec", number(e.target.value))
                        }
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
