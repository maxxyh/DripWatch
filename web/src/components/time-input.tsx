"use client";

import { useState } from "react";
import { Input } from "@/components/ui/input";
import { liveTimeEntry, timeText } from "@/lib/domain";
import { cn } from "@/lib/utils";

export function TimeInput({
  id,
  seconds,
  onChange,
  disabled,
  className,
  placeholder = "2:30",
  "aria-label": ariaLabel,
}: {
  id: string;
  seconds?: number;
  onChange: (seconds?: number) => void;
  disabled?: boolean;
  className?: string;
  placeholder?: string;
  "aria-label"?: string;
}) {
  const formatted = seconds === undefined ? "" : timeText(seconds);
  const [draft, setDraft] = useState({ source: seconds, text: formatted });
  const text = Object.is(draft.source, seconds) ? draft.text : formatted;

  return (
    <Input
      id={id}
      type="text"
      inputMode="numeric"
      pattern="[0-9:]*"
      disabled={disabled}
      className={cn("font-mono tabular-nums", className)}
      placeholder={placeholder}
      aria-label={ariaLabel}
      value={text}
      onClick={(event) => {
        const input = event.currentTarget;
        input.setSelectionRange(input.value.length, input.value.length);
      }}
      onChange={(event) => {
        const next = liveTimeEntry(event.target.value);
        setDraft({ source: next.seconds, text: next.text });
        onChange(next.seconds);
      }}
      onBlur={() =>
        setDraft({
          source: seconds,
          text: seconds === undefined ? "" : timeText(seconds),
        })
      }
    />
  );
}
