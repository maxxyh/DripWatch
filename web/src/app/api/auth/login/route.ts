import { NextResponse } from "next/server";
import {
  createSession,
  isSameOrigin,
  passcodeMatches,
  SESSION_COOKIE,
} from "@/lib/auth";
export async function POST(request: Request) {
  if (!isSameOrigin(request))
    return NextResponse.json({ error: "Invalid origin" }, { status: 403 });
  if (!request.headers.get("content-type")?.startsWith("application/json"))
    return NextResponse.json({ error: "JSON required" }, { status: 415 });
  const body = await request.json().catch(() => ({}));
  if (
    typeof body.passcode !== "string" ||
    body.passcode.length > 256 ||
    !passcodeMatches(body.passcode)
  )
    return NextResponse.json(
      { error: "That passcode does not match." },
      { status: 401, headers: { "Cache-Control": "no-store" } },
    );
  const response = NextResponse.json(
    { ok: true },
    { headers: { "Cache-Control": "no-store" } },
  );
  response.cookies.set(SESSION_COOKIE, await createSession(), {
    httpOnly: true,
    secure: process.env.NODE_ENV === "production",
    sameSite: "strict",
    path: "/",
    maxAge: 60 * 60 * 24 * 14,
  });
  return response;
}
