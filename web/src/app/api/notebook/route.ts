import { NextResponse } from "next/server";
import { loadNotebook, upsertWithConflict, type Table } from "@/lib/notebook";
import { isSameOrigin, requireSession } from "@/lib/auth";
import { requireSafeMutationTarget } from "@/lib/mutation-target";
export const dynamic = "force-dynamic";
export async function GET() {
  try {
    return NextResponse.json(await loadNotebook(), {
      headers: { "Cache-Control": "private, no-store" },
    });
  } catch (error) {
    return NextResponse.json(
      { error: error instanceof Error ? error.message : "Read failed" },
      {
        status:
          error instanceof Error && error.message === "UNAUTHORIZED"
            ? 401
            : 500,
      },
    );
  }
}
export async function POST(request: Request) {
  try {
    if (!isSameOrigin(request))
      return NextResponse.json({ error: "Invalid origin" }, { status: 403 });
    if (!request.headers.get("content-type")?.startsWith("application/json"))
      return NextResponse.json({ error: "JSON required" }, { status: 415 });
    await requireSession();
    requireSafeMutationTarget();
    const body = await request.json();
    if (!["beans", "brews", "bean_photos", "grinders"].includes(body.table))
      return NextResponse.json({ error: "Invalid table" }, { status: 400 });
    const result = await upsertWithConflict(
      body.table as Table,
      body.row,
      body.originalUpdatedAt,
    );
    return NextResponse.json(result, {
      status: result.ok ? 200 : 409,
      headers: { "Cache-Control": "no-store" },
    });
  } catch (error) {
    return NextResponse.json(
      { error: error instanceof Error ? error.message : "Write failed" },
      {
        status:
          error instanceof Error && error.message === "UNAUTHORIZED"
            ? 401
            : error instanceof Error && error.message === "REMOTE_DEV_WRITES_DISABLED"
              ? 403
              : 500,
      },
    );
  }
}
