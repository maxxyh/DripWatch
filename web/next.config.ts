import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  poweredByHeader: false,
  allowedDevOrigins: ["127.0.0.1"],
  experimental: { typedEnv: true },
  serverExternalPackages: ["sharp"],
  images: {
    loader: "custom",
    loaderFile: "./src/lib/image-loader.ts",
    deviceSizes: [420, 640, 828, 1080, 1400],
    imageSizes: [160, 256, 384],
  },
};

export default nextConfig;
