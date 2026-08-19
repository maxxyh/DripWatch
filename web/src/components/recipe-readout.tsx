import {
  CircleDot,
  Clock,
  Disc3,
  Divide,
  Droplet,
  Droplets,
  Flame,
  Hourglass,
  Scale,
  Thermometer,
  Timer,
  CupSoda,
  type LucideIcon,
} from "lucide-react";
import { cn } from "@/lib/utils";
import type { Pour, Recipe } from "@/lib/domain";
import {
  effectiveWater,
  gramText,
  grind,
  grindDisplay,
  ratioText,
  suggestedTargets,
  timeText,
} from "@/lib/domain";

type Chip = { icon: LucideIcon; text: string };

/// The parameters of a recipe as icon + value pills — the everyday, scannable form, mirroring
/// the native app's RecipeReadout. Never a single dense "·"-joined line: each value gets its own
/// icon so the unit doesn't have to be spelled out in words next to it.
function chips(r: Recipe): Chip[] {
  const list: Chip[] = [];
  const g = grind(r);
  // Full grinder + dial, never dial alone — CLAUDE.md's grind invariant: deltas are annotations
  // only, the absolute setting always stays visible.
  if (g) list.push({ icon: Disc3, text: grindDisplay(g) });
  if (r.waterTempC !== undefined)
    list.push({ icon: Thermometer, text: `${r.waterTempC}°C` });
  if (r.doseGrams !== undefined)
    list.push({ icon: Scale, text: `${gramText(r.doseGrams)}g` });
  if (r.yieldGrams !== undefined)
    list.push({ icon: CupSoda, text: `→ ${gramText(r.yieldGrams)}g` });
  if (r.doseGrams !== undefined && r.yieldGrams !== undefined)
    list.push({
      icon: Divide,
      text: `1:${ratioText(r.yieldGrams / r.doseGrams)}`,
    });
  if (r.ratio !== undefined)
    list.push({ icon: Divide, text: `1:${ratioText(r.ratio)}` });
  const water = effectiveWater(r);
  if (r.doseGrams !== undefined && water !== undefined)
    list.push({ icon: Droplet, text: `${gramText(water)}g` });
  if (r.pourCount !== undefined)
    list.push({
      icon: Droplets,
      text: `${r.pourCount} pour${r.pourCount === 1 ? "" : "s"}`,
    });
  if (r.shotTimeSec !== undefined)
    list.push({ icon: Timer, text: `${timeText(r.shotTimeSec)} shot` });
  if (r.preInfusionSec !== undefined)
    list.push({ icon: CircleDot, text: `PI ${r.preInfusionSec}s` });
  if (r.surfWaitSec !== undefined)
    list.push({ icon: Clock, text: `surf ${r.surfWaitSec}s` });
  if (r.steamModeSec !== undefined)
    list.push({ icon: Flame, text: `steam ${r.steamModeSec}s` });
  if (r.bloomTimeSec !== undefined)
    list.push({ icon: Timer, text: `bloom ${timeText(r.bloomTimeSec)}` });
  if (r.totalDrawdownSec !== undefined)
    list.push({ icon: Hourglass, text: `TDD ${timeText(r.totalDrawdownSec)}` });
  return list;
}

/// Just the pills — used wherever a recipe needs a compact glance without the pour breakdown
/// (the live brewing screen's header, for instance).
export function RecipeChips({
  recipe,
  className,
}: {
  recipe: Recipe;
  className?: string;
}) {
  const list = chips(recipe);
  if (!list.length)
    return (
      <p className="text-sm text-muted-foreground">Recipe details not set</p>
    );
  return (
    <div className={cn("flex flex-wrap gap-2", className)}>
      {list.map(({ icon: Icon, text }, i) => (
        <span
          key={i}
          className="inline-flex items-center gap-1.5 rounded-full border bg-muted/50 px-2.5 py-1 text-sm font-medium"
        >
          <Icon className="size-3.5 text-muted-foreground" aria-hidden />
          {text}
        </span>
      ))}
    </div>
  );
}

/// Each timed pour as a segment on a 0→total bar, proportional to its actual seconds — so the
/// rhythm (pours vs. the drawdown gaps between them) is legible at a glance, not just the
/// sequence. Mirrors the native app's PourTimeline.
function PourTimeline({ pours, totalSec }: { pours: Pour[]; totalSec: number }) {
  const timed = pours.filter((p) => p.startSec !== undefined && p.endSec !== undefined);
  if (!timed.length || totalSec <= 0) return null;
  return (
    <div className="flex flex-col gap-1">
      <div
        className="relative h-1.5 rounded-full bg-muted"
        role="img"
        aria-label={`Pour timeline: ${timed
          .map((p) => `pour ${p.order}, ${timeText(p.startSec!)} to ${timeText(p.endSec!)}`)
          .join(", ")}`}
      >
        {timed.map((p) => (
          <span
            key={p.id}
            className="absolute top-0 h-1.5 rounded-full bg-primary"
            style={{
              left: `${(p.startSec! / totalSec) * 100}%`,
              width: `${Math.max(3, ((p.endSec! - p.startSec!) / totalSec) * 100)}%`,
            }}
          />
        ))}
      </div>
      <div className="flex justify-between text-[11px] text-muted-foreground">
        <span>0:00</span>
        <span>{timeText(totalSec)}</span>
      </div>
    </div>
  );
}

/// The change from a prior recipe, as small arrow chips — never replaces the absolute recipe
/// readout above it, just annotates what moved.
export function ChangeChips({ changes }: { changes: string[] }) {
  if (!changes.length) return null;
  return (
    <div className="flex flex-wrap gap-1.5">
      {changes.map((c) => (
        <span
          key={c}
          className="inline-flex items-center gap-1 rounded-full bg-primary/10 px-2 py-0.5 text-xs font-medium text-primary"
        >
          {c}
        </span>
      ))}
    </div>
  );
}

/// A big bold stat readout for the live brewing screen — mirrors the native app's Brewing tab
/// header (large `92°  20g  1:15  300g` with small caption labels underneath), distinct from the
/// icon-chip pills used everywhere else so the numbers you're following mid-pour read at a glance.
export function BrewStatGrid({
  recipe,
  method,
}: {
  recipe: Recipe;
  method: "pourover" | "espresso";
}) {
  const stats: { label: string; value: string }[] = [];
  if (recipe.waterTempC !== undefined)
    stats.push({ label: "temp", value: `${recipe.waterTempC}°` });
  if (recipe.doseGrams !== undefined)
    stats.push({ label: "dose", value: `${gramText(recipe.doseGrams)}g` });
  if (method === "pourover") {
    if (recipe.ratio !== undefined)
      stats.push({ label: "ratio", value: `1:${ratioText(recipe.ratio)}` });
    const water = effectiveWater(recipe);
    if (water !== undefined)
      stats.push({ label: "water", value: `${gramText(water)}g` });
  } else {
    if (recipe.yieldGrams !== undefined)
      stats.push({ label: "yield", value: `${gramText(recipe.yieldGrams)}g` });
    if (recipe.doseGrams !== undefined && recipe.yieldGrams !== undefined)
      stats.push({
        label: "ratio",
        value: `1:${ratioText(recipe.yieldGrams / recipe.doseGrams)}`,
      });
  }
  if (!stats.length) return null;
  return (
    <div className="flex flex-wrap gap-x-6 gap-y-3">
      {stats.map((stat) => (
        <div key={stat.label} className="flex flex-col">
          <span className="font-mono text-3xl font-bold tabular-nums">
            {stat.value}
          </span>
          <span className="text-xs text-muted-foreground">{stat.label}</span>
        </div>
      ))}
    </div>
  );
}

/// The pour plan as plain typed rows (order + optional time window, right-aligned cumulative
/// target) — mirrors the native app's `POUR PLAN` section, not the boxed cards the PWA used to
/// render each pour target in.
export function PourPlanList({ recipe }: { recipe: Recipe }) {
  const savedTargets = recipe.pours.map((pour) => pour.toGrams);
  const targets =
    savedTargets.length && savedTargets.every((value) => value !== undefined)
      ? (savedTargets as number[])
      : suggestedTargets(recipe, recipe.pourCount ?? 0);
  if (!targets.length) return null;
  const summary = [
    recipe.bloomTimeSec !== undefined ? `bloom ${timeText(recipe.bloomTimeSec)}` : null,
    recipe.pourCount !== undefined
      ? `${recipe.pourCount} pour${recipe.pourCount === 1 ? "" : "s"}`
      : null,
    recipe.totalDrawdownSec !== undefined
      ? `TDD ${timeText(recipe.totalDrawdownSec)}`
      : null,
  ]
    .filter(Boolean)
    .join(" · ");
  return (
    <div className="flex flex-col gap-1.5">
      <div className="flex items-baseline justify-between gap-2">
        <span className="text-xs font-semibold tracking-wide text-muted-foreground uppercase">
          Pour plan
        </span>
        {summary && (
          <span className="text-xs text-muted-foreground">{summary}</span>
        )}
      </div>
      {targets.map((target, index) => {
        const pour = recipe.pours[index];
        return (
          <div
            key={pour?.id ?? index}
            className="flex items-center justify-between border-b border-border/40 py-1.5 last:border-b-0"
          >
            <div className="flex items-center gap-2">
              <span className="font-mono text-sm font-bold text-primary">
                #{index + 1}
              </span>
              {pour?.startSec !== undefined && (
                <span className="text-xs text-muted-foreground">
                  {timeText(pour.startSec)}
                  {pour.endSec !== undefined ? `–${timeText(pour.endSec)}` : ""}
                </span>
              )}
              {pour?.style && (
                <span className="text-xs text-muted-foreground">{pour.style}</span>
              )}
            </div>
            <span className="font-mono text-base font-semibold tabular-nums">
              {gramText(target)}g
            </span>
          </div>
        );
      })}
    </div>
  );
}

/// A compact, complete readout of a recipe's absolute values: chips, the pour targets and their
/// timeline, and any technique notes. Read-only — used for the pending plan and every history
/// entry, never for editing.
export function RecipeReadout({ recipe }: { recipe: Recipe }) {
  const savedTargets = recipe.pours.map((pour) => pour.toGrams);
  const targets =
    savedTargets.length && savedTargets.every((value) => value !== undefined)
      ? (savedTargets as number[])
      : suggestedTargets(recipe, recipe.pourCount ?? 0);
  const total =
    recipe.totalDrawdownSec ??
    Math.max(0, ...recipe.pours.map((p) => p.endSec ?? 0));
  return (
    <div className="flex flex-col gap-3">
      <RecipeChips recipe={recipe} />
      {targets.length > 0 && (
        <p
          className="font-mono text-sm text-muted-foreground"
          aria-label={`Cumulative pour targets: ${targets.join(", ")} grams`}
        >
          {targets.map((t) => `${Math.round(t)}g`).join(" → ")}
        </p>
      )}
      <PourTimeline pours={recipe.pours} totalSec={total} />
      {recipe.notes && (
        <p className="text-sm text-muted-foreground">“{recipe.notes}”</p>
      )}
    </div>
  );
}
