import { NextResponse } from "next/server";
import { isSameOrigin, SESSION_COOKIE } from "@/lib/auth";
export async function POST(request: Request) {
  if (!isSameOrigin(request))
    return NextResponse.json({ error: "Invalid origin" }, { status: 403 });
  const response = NextResponse.json(
    { ok: true },
    { headers: { "Cache-Control": "no-store", "Clear-Site-Data": '"cache"' } },
  );
  response.cookies.set(SESSION_COOKIE, "", {
    httpOnly: true,
    secure: process.env.NODE_ENV === "production",
    sameSite: "strict",
    expires: new Date(0),
    path: "/",
  });
  return response;
}
