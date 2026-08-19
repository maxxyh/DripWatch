"use client";

import { useState } from "react";
import { Minus, Plus } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";

type NumericStepperProps = {
  id: string;
  value?: number;
  onChange: (value?: number) => void;
  step?: number;
  min?: number;
  max?: number;
  disabled?: boolean;
  integer?: boolean;
  className?: string;
};

/// Rounds to the field's own step precision and trims a trailing ".0" — a value computed from
/// other fields (e.g. total water = dose × ratio) can otherwise carry many floating-point decimal
/// places (`312.6165…`) that no reasonable column width can fit, mirroring iOS's
/// `.precision(.fractionLength(0...1))` display formatting.
function display(value: number | undefined, precision: number) {
  if (value === undefined) return "";
  let out = value.toFixed(precision);
  if (precision > 0 && out.includes(".")) out = out.replace(/0+$/, "").replace(/\.$/, "");
  return out;
}

export function NumericStepper({
  id,
  value,
  onChange,
  step = 1,
  min,
  max,
  disabled,
  integer = Number.isInteger(step),
  className,
}: NumericStepperProps) {
  const precision = String(step).split(".")[1]?.length ?? 0;
  const [draft, setDraft] = useState(() => ({
    source: value,
    text: display(value, precision),
  }));
  const text = Object.is(draft.source, value) ? draft.text : display(value, precision);
  const clamp = (candidate: number) =>
    Math.min(max ?? Infinity, Math.max(min ?? -Infinity, candidate));
  const bump = (direction: -1 | 1) => {
    const candidate = clamp((value ?? 0) + direction * step);
    const next = Number(candidate.toFixed(precision));
    setDraft({ source: next, text: display(next, precision) });
    onChange(next);
  };
  return (
    <div
      className={`flex h-11 min-w-0 items-stretch overflow-hidden rounded-lg border border-input bg-transparent ${className ?? ""}`}
    >
      <Button
        type="button"
        variant="ghost"
        size="icon"
        className="h-full w-11 shrink-0 rounded-none text-primary hover:bg-primary/10 hover:text-primary disabled:opacity-30"
        disabled={disabled || (min !== undefined && (value ?? 0) <= min)}
        aria-label={`Decrease ${id}`}
        onClick={() => bump(-1)}
      >
        <Minus className="size-4" />
      </Button>
      <Input
        id={id}
        type="text"
        inputMode={integer ? "numeric" : "decimal"}
        pattern={integer ? "-?[0-9]*" : "-?[0-9]*[.,]?[0-9]*"}
        disabled={disabled}
        className="h-full min-w-0 flex-1 rounded-none border-x border-input bg-transparent px-1 text-center font-mono tabular-nums shadow-none focus-visible:ring-0"
        value={text}
        onChange={(event) => {
          const raw = event.target.value.replace(",", ".");
          if (!/^-?(?:\d+)?(?:\.\d*)?$/.test(raw)) return;
          if (raw === "") {
            setDraft({ source: undefined, text: "" });
            onChange(undefined);
            return;
          }
          if (raw === "-" || raw === "." || raw === "-.") {
            setDraft({ source: value, text: raw });
            return;
          }
          const parsed = clamp(Number(raw));
          if (!Number.isFinite(parsed)) return;
          const next = integer ? Math.trunc(parsed) : parsed;
          setDraft({ source: next, text: raw });
          onChange(next);
        }}
        onBlur={() => setDraft({ source: value, text: display(value, precision) })}
      />
      <Button
        type="button"
        variant="ghost"
        size="icon"
        className="h-full w-11 shrink-0 rounded-none text-primary hover:bg-primary/10 hover:text-primary disabled:opacity-30"
        disabled={disabled || (max !== undefined && (value ?? 0) >= max)}
        aria-label={`Increase ${id}`}
        onClick={() => bump(1)}
      >
        <Plus className="size-4" />
      </Button>
    </div>
  );
}
