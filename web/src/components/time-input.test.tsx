import { fireEvent, render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import { TimeInput } from "./time-input";

describe("TimeInput", () => {
  it("places the caret at the end when an existing time is clicked", () => {
    render(<TimeInput id="drawdown" seconds={0} onChange={vi.fn()} />);
    const input = screen.getByRole("textbox") as HTMLInputElement;
    input.setSelectionRange(1, 1);

    fireEvent.click(input);

    expect(input.selectionStart).toBe(input.value.length);
    expect(input.selectionEnd).toBe(input.value.length);
  });
});
