import sharp from "sharp";

export const MAX_PHOTO_DIMENSION = 1400;

export async function validateNormalizedJpeg(bytes: Uint8Array) {
  try {
    const metadata = await sharp(bytes, {
      failOn: "error",
      limitInputPixels: MAX_PHOTO_DIMENSION * MAX_PHOTO_DIMENSION,
    }).metadata();
    return (
      metadata.format === "jpeg" &&
      !!metadata.width &&
      !!metadata.height &&
      metadata.width <= MAX_PHOTO_DIMENSION &&
      metadata.height <= MAX_PHOTO_DIMENSION
    );
  } catch {
    return false;
  }
}
