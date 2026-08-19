"use client";

import { useId } from "react";
import { X } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Field, FieldLabel } from "@/components/ui/field";
import { Input } from "@/components/ui/input";
import { cn } from "@/lib/utils";

/// A term chip-list: type a word, press Enter (or blur) to add it as a chip, tap a chip to
/// remove it. Shared by taste terms and bean flavor tags so both use the same input, rather than
/// one taking a plain comma-separated text field.
export function TermField({
  label,
  values,
  tone,
  placeholder,
  onAdd,
  onRemove,
}: {
  label: string;
  values: string[];
  tone?: "positive" | "negative";
  placeholder?: string;
  onAdd: (v: string) => void;
  onRemove: (v: string) => void;
}) {
  const inputId = useId();
  return (
    <Field>
      <FieldLabel htmlFor={inputId}>{label}</FieldLabel>
      <Input
        id={inputId}
        placeholder={placeholder}
        onBlur={(event) => {
          onAdd(event.currentTarget.value);
          event.currentTarget.value = "";
        }}
        onKeyDown={(e) => {
          if (e.key === "Enter") {
            e.preventDefault();
            onAdd(e.currentTarget.value);
            e.currentTarget.value = "";
          }
        }}
      />
      <div className="flex flex-wrap gap-2">
        {values.map((v) => (
          <Button
            key={v}
            type="button"
            size="sm"
            variant="outline"
            className={cn(
              tone === "positive" && "text-positive",
              tone === "negative" && "text-negative",
            )}
            onClick={() => onRemove(v)}
          >
            {tone === "positive" ? "+ " : tone === "negative" ? "− " : ""}
            {v}
            <X data-icon="inline-end" />
          </Button>
        ))}
      </div>
    </Field>
  );
}
