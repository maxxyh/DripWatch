import { beforeEach, describe, expect, it, vi } from "vitest";

const { redirectMock, hasSessionMock } = vi.hoisted(() => ({
  redirectMock: vi.fn((target: string) => {
    throw new Error(`NEXT_REDIRECT:${target}`);
  }),
  hasSessionMock: vi.fn<() => Promise<boolean>>(),
}));

vi.mock("next/navigation", () => ({ redirect: redirectMock }));
vi.mock("@/lib/auth", () => ({
  SESSION_COOKIE: "dripwatch_session",
  createSession: vi.fn(async () => "signed-test-jwt"),
  isSameOrigin: vi.fn(() => true),
  passcodeMatches: vi.fn((value: string) => value === "test-passcode"),
  hasSession: hasSessionMock,
}));

import { POST as loginPost } from "@/app/api/auth/login/route";
import { POST as logoutPost } from "@/app/api/auth/logout/route";
import Login from "@/app/login/page";

describe("auth cookie policy and /login redirect", () => {
  beforeEach(() => {
    redirectMock.mockClear();
    hasSessionMock.mockReset();
  });

  it("sets the session cookie with SameSite=Lax on login", async () => {
    const response = await loginPost(
      new Request("http://localhost:3000/api/auth/login", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ passcode: "test-passcode" }),
      }),
    );

    expect(response.status).toBe(200);
    const cookie = response.headers.get("set-cookie") ?? "";
    expect(cookie).toContain("dripwatch_session=signed-test-jwt");
    expect(cookie).toContain("HttpOnly");
    expect(cookie).toContain("Path=/");
    expect(cookie).toMatch(/SameSite=lax/i);
    expect(cookie).toContain("Max-Age=1209600");
  });

  it("clears the session cookie with SameSite=Lax on logout", async () => {
    const response = await logoutPost(
      new Request("http://localhost:3000/api/auth/logout", {
        method: "POST",
      }),
    );

    expect(response.status).toBe(200);
    const cookie = response.headers.get("set-cookie") ?? "";
    expect(cookie).toContain("dripwatch_session=;");
    expect(cookie).toMatch(/SameSite=lax/i);
  });

  it("redirects authenticated visitors on /login to safe next path", async () => {
    hasSessionMock.mockResolvedValue(true);

    await expect(
      Login({ searchParams: Promise.resolve({ next: "/beans/abc" }) }),
    ).rejects.toThrow("NEXT_REDIRECT:/beans/abc");
    expect(redirectMock).toHaveBeenCalledWith("/beans/abc");
  });

  it("redirects authenticated visitors on /login to / when next is missing or unsafe", async () => {
    hasSessionMock.mockResolvedValue(true);

    await expect(
      Login({ searchParams: Promise.resolve({}) }),
    ).rejects.toThrow("NEXT_REDIRECT:/");

    await expect(
      Login({ searchParams: Promise.resolve({ next: "//evil.example" }) }),
    ).rejects.toThrow("NEXT_REDIRECT:/");

    await expect(
      Login({ searchParams: Promise.resolve({ next: "/login" }) }),
    ).rejects.toThrow("NEXT_REDIRECT:/");
  });

  it("renders the login page when unauthenticated", async () => {
    hasSessionMock.mockResolvedValue(false);

    const element = await Login({
      searchParams: Promise.resolve({ next: "/beans/abc" }),
    });

    expect(element).toBeTruthy();
    expect(redirectMock).not.toHaveBeenCalled();
  });
});
