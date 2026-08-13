import { defineConfig } from "vitest/config";
import path from "node:path";
export default defineConfig({
  test: {
    environment: "jsdom",
    include: ["src/**/*.test.ts", "src/**/*.test.tsx"],
    exclude: ["e2e/**"],
    coverage: { provider: "v8", include: ["src/lib/domain.ts"] },
  },
  resolve: { alias: { "@": path.resolve(__dirname, "src") } },
});
