export function safeNextPath(
  raw: string | string[] | null | undefined,
): string {
  const value = Array.isArray(raw) ? raw[0] : raw;
  if (
    !value ||
    !value.startsWith("/") ||
    value.startsWith("//") ||
    /[\u0000-\u001f\u007f]/.test(value)
  ) {
    return "/";
  }
  try {
    const parsed = new URL(value, "http://localhost");
    if (
      parsed.origin !== "http://localhost" ||
      parsed.pathname === "/login" ||
      parsed.pathname.startsWith("/login/")
    ) {
      return "/";
    }
    return `${parsed.pathname}${parsed.search}${parsed.hash}`;
  } catch {
    return "/";
  }
}
