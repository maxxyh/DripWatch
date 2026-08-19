"use client";

import { useRef } from "react";
import { cn } from "@/lib/utils";

/// A horizontal, draggable ruler for a stepless grinder — scrub the strip so the value under the
/// fixed centre indicator changes, snapping to `step`. Mirrors the native app's `GrindRuler`
/// (a scrubbable strip rather than a plain min/max slider), where the setting is a continuous
/// number rather than counted clicks.
const STEP = 0.5;
const PX_PER_STEP = 16;
const PX_PER_UNIT = PX_PER_STEP / STEP;
const TICK_SPAN = 14; // units rendered each side of the current value

export function GrindRuler({
  value,
  onChange,
  min = 0,
  max = 100,
  className,
}: {
  value: number;
  onChange: (value: number) => void;
  min?: number;
  max?: number;
  className?: string;
}) {
  const drag = useRef<{ pointerId: number; startX: number; startValue: number } | null>(null);

  const clampSnap = (raw: number) => {
    const snapped = Math.round(raw / STEP) * STEP;
    return Math.min(max, Math.max(min, snapped));
  };

  const onPointerDown = (event: React.PointerEvent<HTMLDivElement>) => {
    event.currentTarget.setPointerCapture(event.pointerId);
    drag.current = { pointerId: event.pointerId, startX: event.clientX, startValue: value };
  };
  const onPointerMove = (event: React.PointerEvent<HTMLDivElement>) => {
    if (!drag.current || drag.current.pointerId !== event.pointerId) return;
    const deltaPx = event.clientX - drag.current.startX;
    const next = clampSnap(drag.current.startValue - deltaPx / PX_PER_UNIT);
    if (next !== value) onChange(next);
  };
  const onPointerUp = (event: React.PointerEvent<HTMLDivElement>) => {
    if (drag.current?.pointerId === event.pointerId) drag.current = null;
  };
  const onKeyDown = (event: React.KeyboardEvent<HTMLDivElement>) => {
    if (event.key === "ArrowRight" || event.key === "ArrowUp") {
      event.preventDefault();
      onChange(clampSnap(value + STEP));
    } else if (event.key === "ArrowLeft" || event.key === "ArrowDown") {
      event.preventDefault();
      onChange(clampSnap(value - STEP));
    }
  };

  const lo = Math.max(min, Math.ceil((value - TICK_SPAN) / STEP) * STEP);
  const hi = Math.min(max, Math.floor((value + TICK_SPAN) / STEP) * STEP);
  const ticks: number[] = [];
  for (let t = lo; t <= hi + 0.0001; t = Math.round((t + STEP) * 1000) / 1000) ticks.push(t);

  return (
    <div
      role="slider"
      tabIndex={0}
      aria-label="Grind setting"
      aria-valuemin={min}
      aria-valuemax={max}
      aria-valuenow={value}
      className={cn(
        "relative h-14 touch-none overflow-hidden rounded-lg bg-primary/[0.06] select-none",
        className,
      )}
      onPointerDown={onPointerDown}
      onPointerMove={onPointerMove}
      onPointerUp={onPointerUp}
      onPointerCancel={onPointerUp}
      onKeyDown={onKeyDown}
    >
      {ticks.map((t) => {
        const isMajor = Math.abs(t % 1) < 0.001;
        return (
          <div
            key={t}
            className="absolute bottom-0 flex flex-col items-center"
            style={{
              left: `calc(50% + ${(t - value) * PX_PER_UNIT}px)`,
              transform: "translateX(-50%)",
            }}
          >
            {isMajor && (
              <span className="mb-0.5 font-mono text-[10px] text-muted-foreground tabular-nums">
                {Math.round(t)}
              </span>
            )}
            <span
              className={cn(
                "w-px bg-foreground/35",
                isMajor ? "h-[18px]" : "h-[10px]",
              )}
            />
          </div>
        );
      })}
      <div className="pointer-events-none absolute inset-y-1.5 left-1/2 w-px -translate-x-1/2 bg-primary" />
      <div className="pointer-events-none absolute top-0 left-1/2 -translate-x-1/2 text-primary">
        <svg width="9" height="6" viewBox="0 0 9 6" fill="currentColor" aria-hidden>
          <path d="M4.5 6 0 0h9z" />
        </svg>
      </div>
    </div>
  );
}
