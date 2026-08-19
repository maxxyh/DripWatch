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
