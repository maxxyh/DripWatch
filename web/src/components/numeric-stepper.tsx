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

const display = (value?: number) => (value === undefined ? "" : String(value));

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
  const [draft, setDraft] = useState(() => ({
    source: value,
    text: display(value),
  }));
  const text = Object.is(draft.source, value) ? draft.text : display(value);
  const clamp = (candidate: number) =>
    Math.min(max ?? Infinity, Math.max(min ?? -Infinity, candidate));
  const bump = (direction: -1 | 1) => {
    const precision = String(step).split(".")[1]?.length ?? 0;
    const candidate = clamp((value ?? 0) + direction * step);
    const next = Number(candidate.toFixed(precision));
    setDraft({ source: next, text: display(next) });
    onChange(next);
  };
  return (
    <div className={`flex min-w-0 items-stretch ${className ?? ""}`}>
      <Button
        type="button"
        variant="outline"
        size="icon"
        className="shrink-0 rounded-r-none border-r-0"
        disabled={disabled || (min !== undefined && (value ?? 0) <= min)}
        aria-label={`Decrease ${id}`}
        onClick={() => bump(-1)}
      >
        <Minus />
      </Button>
      <Input
        id={id}
        type="text"
        inputMode={integer ? "numeric" : "decimal"}
        pattern={integer ? "-?[0-9]*" : "-?[0-9]*[.,]?[0-9]*"}
        disabled={disabled}
        className="min-w-0 rounded-none text-center font-mono tabular-nums"
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
        onBlur={() => setDraft({ source: value, text: display(value) })}
      />
      <Button
        type="button"
        variant="outline"
        size="icon"
        className="shrink-0 rounded-l-none border-l-0"
        disabled={disabled || (max !== undefined && (value ?? 0) >= max)}
        aria-label={`Increase ${id}`}
        onClick={() => bump(1)}
      >
        <Plus />
      </Button>
    </div>
  );
}
