import { NextResponse } from "next/server";
import { createHash } from "node:crypto";
import sharp from "sharp";
import { isSameOrigin, requireSession } from "@/lib/auth";
import { supabase } from "@/lib/supabase";
import { validateNormalizedJpeg, MAX_PHOTO_DIMENSION } from "@/lib/photo-validation";
const allowed = new Set(["bean-photos", "brew-photos"]);
const canonicalPath =
  /^([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})\/([0-9a-f]{64})\.jpg$/;
const MIN_RESIZE_WIDTH = 16;
const DEFAULT_QUALITY = 75;
const MIN_QUALITY = 40;
const MAX_QUALITY = 90;
function parseVariant(url: URL) {
  const rawWidth = url.searchParams.get("w");
  const parsedWidth = rawWidth === null ? NaN : Number.parseInt(rawWidth, 10);
  const width = Number.isFinite(parsedWidth)
    ? Math.min(Math.max(parsedWidth, MIN_RESIZE_WIDTH), MAX_PHOTO_DIMENSION)
    : null;
  const rawQuality = url.searchParams.get("q");
  const parsedQuality =
    rawQuality === null ? NaN : Number.parseInt(rawQuality, 10);
  const quality = Number.isFinite(parsedQuality)
    ? Math.min(Math.max(parsedQuality, MIN_QUALITY), MAX_QUALITY)
    : DEFAULT_QUALITY;
  return { width, quality };
}
export async function GET(
  request: Request,
  { params }: { params: Promise<{ bucket: string; path: string[] }> },
) {
  try {
    await requireSession();
    const { bucket, path } = await params;
    if (!allowed.has(bucket)) return new NextResponse(null, { status: 404 });
    const relativePath = path.join("/");
    const match = canonicalPath.exec(relativePath);
    if (!match) return new NextResponse(null, { status: 404 });
    const db = supabase();
    let referencedPath: string | null = null;
    let deletedAt: string | null = null;
    if (bucket === "bean-photos") {
      const reference = await db
        .from("bean_photos")
        .select("remote_path,deleted_at")
        .eq("id", match[1])
        .maybeSingle();
      if (reference.error || !reference.data)
        return new NextResponse(null, { status: 404 });
      const row = reference.data as unknown as {
        remote_path: string | null;
        deleted_at: string | null;
      };
      referencedPath = row.remote_path;
      deletedAt = row.deleted_at;
    } else {
      const reference = await db
        .from("brews")
        .select("photo_path,deleted_at")
        .eq("id", match[1])
        .maybeSingle();
      if (reference.error || !reference.data)
        return new NextResponse(null, { status: 404 });
      const row = reference.data as unknown as {
        photo_path: string | null;
        deleted_at: string | null;
      };
      referencedPath = row.photo_path;
      deletedAt = row.deleted_at;
    }
    if (deletedAt || referencedPath !== relativePath)
      return new NextResponse(null, { status: 404 });
    const { width, quality } = parseVariant(new URL(request.url));
    const etag = width ? `"${match[2]}-w${width}-q${quality}"` : `"${match[2]}"`;
    const cacheHeaders = {
      "Cache-Control": "private, max-age=31536000, immutable",
      ETag: etag,
      "X-Content-Type-Options": "nosniff",
      "Cross-Origin-Resource-Policy": "same-origin",
    };
    if (request.headers.get("if-none-match") === etag)
      return new NextResponse(null, { status: 304, headers: cacheHeaders });
    const { data, error } = await supabase()
      .storage.from(bucket)
      .download(relativePath);
    if (error) throw error;
    const original = await data.arrayBuffer();
    const body = width
      ? await sharp(Buffer.from(original), {
          failOn: "error",
          limitInputPixels: MAX_PHOTO_DIMENSION * MAX_PHOTO_DIMENSION,
        })
          .resize({ width, withoutEnlargement: true })
          .jpeg({ quality })
          .toBuffer()
      : original;
    return new NextResponse(body, {
      headers: {
        "Content-Type": "image/jpeg",
        "Content-Disposition": "inline",
        ...cacheHeaders,
      },
    });
  } catch (error) {
    return NextResponse.json(
      { error: error instanceof Error ? error.message : "Photo failed" },
      {
        status:
          error instanceof Error && error.message === "UNAUTHORIZED"
            ? 401
            : 404,
      },
    );
  }
}
export async function PUT(
  request: Request,
  { params }: { params: Promise<{ bucket: string; path: string[] }> },
) {
  try {
    if (!isSameOrigin(request))
      return NextResponse.json({ error: "Invalid origin" }, { status: 403 });
    await requireSession();
    const { bucket, path } = await params;
    if (!allowed.has(bucket)) return new NextResponse(null, { status: 404 });
    const relativePath = path.join("/");
    const match = canonicalPath.exec(relativePath);
    if (!match)
      return NextResponse.json(
        { error: "Invalid photo path." },
        { status: 400 },
      );
    const bytes = await request.arrayBuffer();
    if (!bytes.byteLength || bytes.byteLength > 8_000_000)
      return NextResponse.json(
        { error: "Photo must be under 8 MB." },
        { status: 400 },
      );
    const view = new Uint8Array(bytes);
    const digest = createHash("sha256").update(view).digest("hex");
    if (
      view[0] !== 0xff ||
      view[1] !== 0xd8 ||
      view[2] !== 0xff ||
      digest !== match[2]
    )
      return NextResponse.json(
        { error: "Photo bytes do not match the canonical JPEG path." },
        { status: 400 },
      );
    if (!(await validateNormalizedJpeg(view)))
      return NextResponse.json(
        { error: "JPEG dimensions must be between 1 and 1400 pixels." },
        { status: 400 },
      );
    const { error } = await supabase()
      .storage.from(bucket)
      .upload(relativePath, bytes, {
        contentType: "image/jpeg",
        upsert: true,
      });
    if (error) throw error;
    return NextResponse.json(
      { ok: true },
      { headers: { "Cache-Control": "no-store" } },
    );
  } catch (error) {
    return NextResponse.json(
      { error: error instanceof Error ? error.message : "Upload failed" },
      {
        status:
          error instanceof Error && error.message === "UNAUTHORIZED"
            ? 401
            : 500,
      },
    );
  }
}
