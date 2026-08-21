import "@testing-library/jest-dom/vitest";
import { describe, expect, it, vi, afterEach } from "vitest";
import { render, screen, cleanup } from "@testing-library/react";
import { useTheme } from "next-themes";
import { ThemeSelect } from "./theme-select";

afterEach(cleanup);

const setTheme = vi.fn();

vi.mock("next-themes", () => ({
  useTheme: vi.fn(() => ({
    theme: "system",
    setTheme,
    themes: ["system", "light", "dark"],
  })),
  ThemeProvider: ({ children }: { children: React.ReactNode }) => <>{children}</>,
}));

describe("ThemeSelect", () => {
  it("renders the current theme with an icon and label", () => {
    render(<ThemeSelect />);
    const trigger = screen.getByRole("combobox", { name: /theme/i });
    expect(trigger).toHaveTextContent("System");
    expect(trigger.querySelector("svg")).toBeInTheDocument();
  });

  it("renders the light theme label and icon", () => {
    vi.mocked(useTheme).mockReturnValue({
      theme: "light",
      setTheme,
      themes: ["system", "light", "dark"],
    });
    render(<ThemeSelect />);
    const trigger = screen.getByRole("combobox", { name: /theme/i });
    expect(trigger).toHaveTextContent("Light");
  });

  it("renders the dark theme label and icon", () => {
    vi.mocked(useTheme).mockReturnValue({
      theme: "dark",
      setTheme,
      themes: ["system", "light", "dark"],
    });
    render(<ThemeSelect />);
    const trigger = screen.getByRole("combobox", { name: /theme/i });
    expect(trigger).toHaveTextContent("Dark");
  });
});
