"use client";
import { useEffect, useRef, useState } from "react";
import {
  Check,
  ChevronDown,
  CircleDot,
  CupSoda,
  Disc3,
  Divide,
  Droplet,
  Droplets,
  Hourglass,
  Scale,
  Thermometer,
  Timer,
  type LucideIcon,
} from "lucide-react";
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
import { Switch } from "@/components/ui/switch";
import { Textarea } from "@/components/ui/textarea";
import { Toggle } from "@/components/ui/toggle";
import { GrindRuler } from "./grind-ruler";
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
import { cn } from "@/lib/utils";

const VALUE_WIDTH = "w-40";

/// One full-width row — icon + label on the left, a compact value/stepper on the right — mirroring
/// the native app's continuous list of plain rows (RecipeEditor.swift's `NumberField`/`DecimalField`)
/// instead of a form of individually bordered, half-width grid cells.
function FieldRow({
  icon: Icon,
  label,
  htmlFor,
  hint,
  valueClassName,
  children,
}: {
  icon: LucideIcon;
  label: string;
  htmlFor?: string;
  hint?: string;
  valueClassName?: string;
  children: React.ReactNode;
}) {
  return (
    <div className="flex items-center justify-between gap-3 py-0.5">
      <FieldLabel
        htmlFor={htmlFor}
        className="flex-1 items-center gap-2 text-sm font-normal text-muted-foreground"
      >
        <Icon className="size-4 shrink-0" aria-hidden />
        <span className="flex flex-col leading-tight">
          {label}
          {hint && (
            <span className="text-xs text-muted-foreground/70">{hint}</span>
          )}
        </span>
      </FieldLabel>
      <div className={cn("shrink-0", valueClassName ?? VALUE_WIDTH)}>
        {children}
      </div>
    </div>
  );
}

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
  function selectGrinder(grinder: GrinderRow) {
    onChange({
      ...recipe,
      grinderName: grinder.name,
      grindClickOffset: grinder.stepless ? 0 : recipe.grindClickOffset,
    });
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
  const stepless = !!selectedGrinder?.stepless;
  return (
    <div className="flex flex-col gap-4">
      <Card>
        <CardHeader>
          <CardTitle>Recipe</CardTitle>
        </CardHeader>
        <CardContent>
          <FieldGroup>
            <div className="flex flex-col gap-3">
              <div className="flex items-center justify-between gap-3">
                <FieldLabel htmlFor="grinder" className="gap-2 text-sm font-normal text-muted-foreground">
                  <Disc3 className="size-4 shrink-0" aria-hidden />
                  Grind
                </FieldLabel>
                {recipe.grinderName && (
                  <span className="truncate font-mono text-sm font-semibold text-primary">
                    {recipe.grinderName}
                    {recipe.grindMajor !== undefined ? ` · ${recipe.grindMajor}` : ""}
                    {recipe.grindClickOffset
                      ? ` (${recipe.grindClickOffset > 0 ? "+" : ""}${recipe.grindClickOffset})`
                      : ""}
                  </span>
                )}
              </div>
              {knownGrinders.length > 0 && (
                <div className="flex flex-wrap gap-2">
                  {knownGrinders.map((g) => {
                    const active = recipe.grinderName === g.name;
                    return (
                      <button
                        key={g.id}
                        type="button"
                        onClick={() => selectGrinder(g)}
                        className={cn(
                          "inline-flex h-9 items-center gap-1.5 rounded-full border px-3 text-sm font-medium transition-colors",
                          active
                            ? "border-primary/40 bg-primary/10 text-primary"
                            : "border-input bg-transparent text-muted-foreground hover:bg-muted",
                        )}
                        aria-pressed={active}
                      >
                        {active && <Check className="size-3.5" aria-hidden />}
                        {g.name}
                      </button>
                    );
                  })}
                </div>
              )}
              <Input
                id="grinder"
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
              {recipe.grinderName?.trim() && (
                <>
                  <div className="flex items-center justify-between py-0.5">
                    <FieldLabel htmlFor="stepless" className="text-sm font-normal text-muted-foreground">
                      Stepless (number, no clicks)
                    </FieldLabel>
                    <Switch
                      id="stepless"
                      checked={stepless}
                      onCheckedChange={setGrinderKind}
                    />
                  </div>
                  {stepless ? (
                    <div className="flex items-end gap-3">
                      <GrindRuler
                        className="flex-1"
                        value={recipe.grindMajor ?? 0}
                        onChange={(value) => set("grindMajor", value)}
                      />
                      <div className="flex flex-col items-start gap-0.5">
                        <span className="text-xs font-semibold text-muted-foreground">
                          Setting
                        </span>
                        <Input
                          type="text"
                          inputMode="decimal"
                          className="w-20 px-1 text-center font-mono tabular-nums"
                          value={recipe.grindMajor ?? ""}
                          onChange={(event) => {
                            const raw = event.target.value.replace(",", ".");
                            if (!/^\d*\.?\d*$/.test(raw)) return;
                            const parsed = raw === "" ? undefined : Number(raw);
                            if (parsed !== undefined && !Number.isFinite(parsed))
                              return;
                            set("grindMajor", parsed);
                          }}
                        />
                      </div>
                    </div>
                  ) : (
                    <>
                      <FieldRow icon={Disc3} label="Dial" htmlFor="dial">
                        <NumericStepper
                          id="dial"
                          step={0.1}
                          min={0}
                          max={60}
                          value={recipe.grindMajor}
                          onChange={(value) => set("grindMajor", value)}
                        />
                      </FieldRow>
                      <FieldRow
                        icon={CircleDot}
                        label="Clicks from dial"
                        hint="+ finer / − coarser"
                        htmlFor="clicks"
                      >
                        <NumericStepper
                          id="clicks"
                          min={-30}
                          max={30}
                          value={recipe.grindClickOffset}
                          onChange={(value) => set("grindClickOffset", value)}
                        />
                      </FieldRow>
                    </>
                  )}
                </>
              )}
            </div>
            <div className="border-t" />
            <FieldRow icon={Scale} label="Dose (g)" htmlFor="dose">
              <NumericStepper
                id="dose"
                step={0.1}
                min={0}
                value={recipe.doseGrams}
                onChange={changeDose}
              />
            </FieldRow>
            {method === "pourover" ? (
              <>
                <FieldRow icon={Thermometer} label="Water (°C)" htmlFor="temp">
                  <NumericStepper
                    id="temp"
                    min={0}
                    value={recipe.waterTempC}
                    onChange={(value) => set("waterTempC", value)}
                  />
                </FieldRow>
                <FieldRow icon={Divide} label="Ratio 1:" htmlFor="ratio">
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
                </FieldRow>
                <FieldRow icon={Droplet} label="Total water (g)" htmlFor="water">
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
                </FieldRow>
                <FieldRow icon={Droplets} label="Pours" htmlFor="pours">
                  <NumericStepper
                    id="pours"
                    min={1}
                    max={12}
                    value={recipe.pourCount}
                    onChange={changeCount}
                  />
                </FieldRow>
                <FieldRow icon={Timer} label="Bloom" htmlFor="bloom">
                  <TimeInput
                    id="bloom"
                    seconds={recipe.bloomTimeSec}
                    onChange={(value) => set("bloomTimeSec", value)}
                  />
                </FieldRow>
                <FieldRow icon={Hourglass} label="Drawdown (TDD)" htmlFor="tdd">
                  <TimeInput
                    id="tdd"
                    seconds={recipe.totalDrawdownSec}
                    onChange={(value) => set("totalDrawdownSec", value)}
                  />
                </FieldRow>
              </>
            ) : (
              <>
                <FieldRow icon={Thermometer} label="Water (°C)" htmlFor="espresso-temp">
                  <NumericStepper
                    id="espresso-temp"
                    min={0}
                    value={recipe.waterTempC}
                    onChange={(value) => set("waterTempC", value)}
                  />
                </FieldRow>
                <FieldRow icon={CupSoda} label="Yield (g)" htmlFor="yield">
                  <NumericStepper
                    id="yield"
                    step={0.1}
                    min={0}
                    value={recipe.yieldGrams}
                    onChange={(value) => set("yieldGrams", value)}
                  />
                </FieldRow>
              </>
            )}
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
                <div className="flex flex-col gap-1">
                  <Toggle
                    variant="outline"
                    size="sm"
                    className="mb-2 self-start"
                    pressed={showTimes}
                    onPressedChange={setShowTimes}
                  >
                    Add pour timings
                  </Toggle>
                  <div className="flex items-center gap-2 px-1 text-xs font-semibold text-muted-foreground/70">
                    <span className="w-6 shrink-0">#</span>
                    {showTimes && <span>start – end</span>}
                    <span className="flex-1" />
                    <span>to (g)</span>
                  </div>
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
                        className="flex flex-col gap-1 border-b border-border/50 py-2 last:border-b-0"
                      >
                        <div className="flex items-center gap-2">
                          <span className="w-6 shrink-0 font-mono text-sm font-bold text-primary">
                            {i + 1}
                          </span>
                          {showTimes && (
                            <>
                              <TimeInput
                                id={`start-${i}`}
                                seconds={pour.startSec}
                                placeholder="start"
                                aria-label={`Pour ${i + 1} start time`}
                                className="h-8 w-16 rounded-md border-0 bg-muted/60 text-center text-xs shadow-none focus-visible:ring-1"
                                onChange={(value) => {
                                  const pours = [...recipe.pours];
                                  pours[i] = { ...pour, startSec: value };
                                  onChange({ ...recipe, pours });
                                }}
                              />
                              <span className="text-xs text-muted-foreground">–</span>
                              <TimeInput
                                id={`end-${i}`}
                                seconds={pour.endSec}
                                placeholder="end"
                                aria-label={`Pour ${i + 1} end time`}
                                className="h-8 w-16 rounded-md border-0 bg-muted/60 text-center text-xs shadow-none focus-visible:ring-1"
                                onChange={(value) => {
                                  const pours = [...recipe.pours];
                                  pours[i] = { ...pour, endSec: value };
                                  onChange({ ...recipe, pours });
                                }}
                              />
                            </>
                          )}
                          <span className="flex-1" />
                          <input
                            id={`pour-${i}`}
                            type="text"
                            inputMode="decimal"
                            aria-label={`Pour ${i + 1} target grams`}
                            className="w-14 border-0 bg-transparent text-right font-mono text-base font-semibold tabular-nums outline-none"
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
                          <span className="text-xs text-muted-foreground">g</span>
                        </div>
                        <input
                          id={`style-${i}`}
                          type="text"
                          placeholder="style / note (centre, aggressive…)"
                          aria-label={`Pour ${i + 1} style or note`}
                          className="border-0 bg-transparent pl-8 text-sm text-muted-foreground outline-none placeholder:text-muted-foreground/50"
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
                      </div>
                    );
                  })}
                </div>
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
