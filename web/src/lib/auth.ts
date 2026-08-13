import "server-only";
import {
  createHash,
  createHmac,
  randomUUID,
  timingSafeEqual,
} from "node:crypto";
import { cookies } from "next/headers";
import { SignJWT, jwtVerify } from "jose";

export const SESSION_COOKIE =
  process.env.NODE_ENV === "production"
    ? "__Host-dripwatch_session"
    : "dripwatch_session";
const digest = (value: string) => createHash("sha256").update(value).digest();
const secret = () => {
  const value = process.env.DRIPWATCH_SESSION_SECRET ?? "";
  if (value.length < 32)
    throw new Error("DRIPWATCH_SESSION_SECRET must be at least 32 characters.");
  return new TextEncoder().encode(value);
};
const passcodeVersion = () =>
  createHmac("sha256", secret())
    .update(process.env.DRIPWATCH_PASSCODE ?? "")
    .digest("base64url")
    .slice(0, 16);
export function passcodeMatches(value: string) {
  return (
    !!process.env.DRIPWATCH_PASSCODE &&
    timingSafeEqual(digest(process.env.DRIPWATCH_PASSCODE), digest(value))
  );
}
export async function createSession() {
  return new SignJWT({ scope: "notebook", passcodeVersion: passcodeVersion() })
    .setProtectedHeader({ alg: "HS256" })
    .setJti(randomUUID())
    .setIssuedAt()
    .setExpirationTime("14d")
    .sign(secret());
}
export async function sessionDetails() {
  try {
    const token = (await cookies()).get(SESSION_COOKIE)?.value;
    if (!token) return null;
    const { payload } = await jwtVerify(token, secret());
    if (
      payload.scope !== "notebook" ||
      payload.passcodeVersion !== passcodeVersion() ||
      !payload.jti ||
      !payload.exp
    )
      return null;
    return { cacheScope: payload.jti, expiresAt: payload.exp * 1000 };
  } catch {
    return null;
  }
}
export async function hasSession() {
  return !!(await sessionDetails());
}
export async function requireSession() {
  if (!(await hasSession())) throw new Error("UNAUTHORIZED");
}
export function isSameOrigin(request: Request) {
  if (process.env.NODE_ENV !== "production") return true;
  const origin = request.headers.get("origin");
  return !!origin && origin === new URL(request.url).origin;
}
