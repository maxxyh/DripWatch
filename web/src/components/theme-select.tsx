"use client";

import { useTheme } from "next-themes";
import { Monitor, Moon, Sun } from "lucide-react";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";

const THEMES = [
  { value: "system", label: "System", icon: Monitor },
  { value: "light", label: "Light", icon: Sun },
  { value: "dark", label: "Dark", icon: Moon },
] as const;

export function ThemeSelect() {
  const { theme = "system", setTheme } = useTheme();
  const selected = THEMES.find((t) => t.value === theme) ?? THEMES[0];
  const SelectedIcon = selected.icon;

  return (
    <Select value={theme} onValueChange={(value) => value && setTheme(value)}>
      <SelectTrigger
        aria-label="Theme"
        className="h-11 gap-2 border-transparent bg-transparent hover:bg-muted hover:text-foreground aria-expanded:bg-muted aria-expanded:text-foreground dark:hover:bg-muted/50"
      >
        <SelectValue>
          <SelectedIcon aria-hidden />
          <span>{selected.label}</span>
        </SelectValue>
      </SelectTrigger>
      <SelectContent>
        {THEMES.map(({ value, label, icon: Icon }) => (
          <SelectItem key={value} value={value}>
            <Icon aria-hidden />
            {label}
          </SelectItem>
        ))}
      </SelectContent>
    </Select>
  );
}
