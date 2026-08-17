export default function dripwatchImageLoader({
  src,
  width,
  quality,
}: {
  src: string;
  width: number;
  quality?: number;
}) {
  if (!src.startsWith("/api/photos/")) return src;
  const params = new URLSearchParams({
    w: String(width),
    q: String(quality ?? 75),
  });
  return `${src}?${params.toString()}`;
}
