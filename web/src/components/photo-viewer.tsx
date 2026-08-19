"use client";

import { useEffect, useRef, useState } from "react";
import { Dialog as DialogPrimitive } from "@base-ui/react/dialog";
import { ChevronLeft, ChevronRight, X } from "lucide-react";
import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";

/// The photo(s) to open full-screen, plus which one is showing. One array serves both a single
/// shot and a swipeable gallery, the same shape the native app's PreviewPhoto carries. Fully
/// controlled — the current index lives wherever `photo` comes from, not inside the viewer —
/// since syncing an internal index from a prop is exactly the derived-state trap React's
/// stricter hooks lint (rightly) rejects both the effect and the ref-comparison way of doing.
export type PreviewPhoto = { urls: string[]; index: number };

const overlayButton = "rounded-full bg-white/15 text-white backdrop-blur hover:bg-white/25";

/// A full-screen, black-backed photo viewer: swipe or use the arrow keys/buttons between several
/// photos, tap the image to toggle a zoom, tap anywhere outside the photo, press Escape, or use
/// the close button to dismiss. Mirrors the native app's PhotoViewer without the pinch/pan
/// gesture math, which the mouse/touch web surface doesn't need for the same effect.
export function PhotoViewer({
  photo,
  onIndexChange,
  onClose,
}: {
  photo: PreviewPhoto | null;
  onIndexChange: (index: number) => void;
  onClose: () => void;
}) {
  const touchStartX = useRef(0);
  const urls = photo?.urls ?? [];
  const count = urls.length;
  const index = photo?.index ?? 0;

  const go = (delta: number) => onIndexChange((index + delta + count) % count);

  useEffect(() => {
    if (!photo || count <= 1) return;
    function onKey(event: KeyboardEvent) {
      if (event.key === "ArrowLeft") go(-1);
      if (event.key === "ArrowRight") go(1);
    }
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [photo, count, index]);

  return (
    <DialogPrimitive.Root
      open={!!photo}
      onOpenChange={(open) => {
        if (!open) onClose();
      }}
    >
      <DialogPrimitive.Portal>
        <DialogPrimitive.Backdrop className="fixed inset-0 z-50 bg-black data-open:animate-in data-open:fade-in-0 data-closed:animate-out data-closed:fade-out-0" />
        <DialogPrimitive.Popup
          className="fixed inset-0 z-50 flex flex-col outline-none"
          onTouchStart={(event) => {
            touchStartX.current = event.touches[0]?.clientX ?? 0;
          }}
          onTouchEnd={(event) => {
            const dx = (event.changedTouches[0]?.clientX ?? 0) - touchStartX.current;
            if (count > 1 && Math.abs(dx) > 50) go(dx < 0 ? 1 : -1);
          }}
        >
          <DialogPrimitive.Title className="sr-only">
            Photo preview
          </DialogPrimitive.Title>
          <div className="flex items-center justify-between p-3">
            {count > 1 ? (
              <span
                className="rounded-full bg-white/15 px-3 py-1 text-sm font-medium text-white backdrop-blur"
                aria-label={`Photo ${index + 1} of ${count}`}
              >
                {index + 1} / {count}
              </span>
            ) : (
              <span />
            )}
            <DialogPrimitive.Close
              render={
                <Button
                  variant="ghost"
                  size="icon"
                  aria-label="Close"
                  className={overlayButton}
                />
              }
            >
              <X />
            </DialogPrimitive.Close>
          </div>
          {/* Tapping this row closes the viewer; the photo itself stops the click from
              reaching here so a tap on the image toggles zoom instead. */}
          <div
            className="relative flex flex-1 items-center justify-center overflow-hidden"
            onClick={onClose}
          >
            {photo && urls[index] && <ZoomableImage key={index} src={urls[index]} />}
            {count > 1 && (
              <>
                <Button
                  variant="ghost"
                  size="icon"
                  aria-label="Previous photo"
                  onClick={(event) => {
                    event.stopPropagation();
                    go(-1);
                  }}
                  className={cn("absolute left-2", overlayButton)}
                >
                  <ChevronLeft />
                </Button>
                <Button
                  variant="ghost"
                  size="icon"
                  aria-label="Next photo"
                  onClick={(event) => {
                    event.stopPropagation();
                    go(1);
                  }}
                  className={cn("absolute right-2", overlayButton)}
                >
                  <ChevronRight />
                </Button>
              </>
            )}
          </div>
        </DialogPrimitive.Popup>
      </DialogPrimitive.Portal>
    </DialogPrimitive.Root>
  );
}

/// One photo with a tap-to-toggle zoom. Keyed by index from the parent so switching photos
/// remounts this (resetting zoom) instead of needing to sync zoom state from a prop. A plain
/// `<img>`, not next/image's `fill` mode: `fill` always occupies its full container regardless
/// of the photo's own aspect ratio, so a letterboxed (non-square) photo left the "outside the
/// photo" tap-to-dismiss area covered by an invisible, still-clickable zoom target. Sizing this
/// element to its own rendered footprint instead means a tap actually lands on the dismiss
/// wrapper wherever the photo itself isn't drawn.
function ZoomableImage({ src }: { src: string }) {
  const [zoomed, setZoomed] = useState(false);
  return (
    <button
      type="button"
      aria-label={zoomed ? "Zoom out" : "Zoom in"}
      className={zoomed ? "cursor-zoom-out" : "cursor-zoom-in"}
      onClick={(event) => {
        event.stopPropagation();
        setZoomed((z) => !z);
      }}
    >
      {/* eslint-disable-next-line @next/next/no-img-element -- needs an intrinsic-size box (see
          above); next/image's `fill` and explicit-dimension modes can't produce one here. */}
      <img
        src={src}
        alt=""
        className={cn(
          "h-auto max-h-[calc(100dvh-4rem)] w-auto max-w-full object-contain transition-transform duration-200",
          zoomed && "scale-150",
        )}
      />
    </button>
  );
}
