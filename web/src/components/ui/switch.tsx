"use client";

import { cn } from "@/lib/utils";

/// A minimal on/off switch (native `<button role="switch">`, no external dependency) — used
/// wherever the native app uses a `Toggle` bound to a boolean, e.g. stepless vs. stepped grind.
export function Switch({
  checked,
  onCheckedChange,
  id,
  disabled,
  className,
}: {
  checked: boolean;
  onCheckedChange: (value: boolean) => void;
  id?: string;
  disabled?: boolean;
  className?: string;
}) {
  return (
    <button
      type="button"
      id={id}
      role="switch"
      aria-checked={checked}
      disabled={disabled}
      onClick={() => onCheckedChange(!checked)}
      className={cn(
        "inline-flex h-7 w-12 shrink-0 items-center rounded-full border border-transparent bg-muted transition-colors outline-none focus-visible:ring-3 focus-visible:ring-ring/50 disabled:pointer-events-none disabled:opacity-50",
        checked && "bg-primary",
        className,
      )}
    >
      <span
        className={cn(
          "size-5 translate-x-1 rounded-full bg-background shadow transition-transform",
          checked && "translate-x-6",
        )}
      />
    </button>
  );
}
