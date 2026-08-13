import { NextResponse } from "next/server";
import { sessionDetails } from "@/lib/auth";

export async function GET() {
  const session = await sessionDetails();
  if (!session)
    return NextResponse.json(
      { error: "Unauthorized" },
      { status: 401, headers: { "Cache-Control": "no-store" } },
    );
  return NextResponse.json(session, {
    headers: { "Cache-Control": "no-store" },
  });
}
