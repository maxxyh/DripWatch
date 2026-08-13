import { NextResponse, type NextRequest } from "next/server";

const sessionCookie =
  process.env.NODE_ENV === "production"
    ? "__Host-dripwatch_session"
    : "dripwatch_session";

export function proxy(request: NextRequest) {
  const path = request.nextUrl.pathname;
  if (
    path === "/login" ||
    path.startsWith("/_next") ||
    path.startsWith("/icons") ||
    path === "/manifest.webmanifest" ||
    path === "/sw.js" ||
    path.startsWith("/api/")
  )
    return NextResponse.next();
  if (!request.cookies.get(sessionCookie)) {
    const url = new URL("/login", request.url);
    url.searchParams.set("next", path);
    return NextResponse.redirect(url);
  }
  return NextResponse.next();
}

export const config = { matcher: ["/((?!favicon.ico).*)"] };
