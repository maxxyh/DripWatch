"use client";

import { useState } from "react";
import { Input } from "@/components/ui/input";
import { liveTimeEntry, timeText } from "@/lib/domain";

export function TimeInput({
  id,
  seconds,
  onChange,
  disabled,
}: {
  id: string;
  seconds?: number;
  onChange: (seconds?: number) => void;
  disabled?: boolean;
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
      className="font-mono tabular-nums"
      placeholder="2:30"
      value={text}
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
