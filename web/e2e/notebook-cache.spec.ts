import { expect, test } from "@playwright/test";

const bean = (name: string) => ({
  id: "00000000-0000-4000-8000-000000000001",
  created_at: "2026-01-01T00:00:00.000Z",
  updated_at: "2026-01-01T00:00:00.000Z",
  deleted_at: null,
  name,
  roaster_name: "Test Roaster",
  country: null,
  region: null,
  farm: null,
  varietal: null,
  process: null,
  roast_level: null,
  roast_date: null,
  roaster_notes: null,
  price_sgd: null,
  bag_size_grams: null,
  my_flavor_tags: [],
  finished_at: null,
  pending_next_pourover: null,
  pending_next_espresso: null,
});
const notebook = (name: string) => ({
  beans: [bean(name)],
  brews: [],
  beanPhotos: [],
  grinders: [],
  loadedAt: new Date().toISOString(),
});

test("a repeat visit paints the cached notebook before the network refresh resolves", async ({
  page,
  context,
}) => {
  await context.addCookies([
    { name: "dripwatch_session", value: "test", domain: "127.0.0.1", path: "/" },
  ]);
  await context.addInitScript(
    ([snapshotKey, leaseKey, snapshot, lease]) => {
      window.localStorage.setItem(snapshotKey as string, snapshot as string);
      window.localStorage.setItem(leaseKey as string, lease as string);
    },
    [
      "dripwatch-notebook-v1",
      "dripwatch-session-lease",
      JSON.stringify(notebook("Cached Bean")),
      JSON.stringify({ cacheScope: "test-scope", expiresAt: Date.now() + 3_600_000 }),
    ] as const,
  );
  await page.route("**/api/notebook", async (route) => {
    await new Promise((resolve) => setTimeout(resolve, 1500));
    await route.fulfill({ json: notebook("Fresh Bean") });
  });

  await page.goto("/");
  // The cached snapshot must render well before the 1500ms mocked fetch
  // resolves — proves the app paints from localStorage instead of blocking
  // on the network round trip.
  await expect(page.getByText("Cached Bean")).toBeVisible({ timeout: 500 });

  // Read-only while the cached snapshot is unconfirmed: mutation entry
  // points render disabled, and we must never falsely claim we're offline
  // just because a background revalidation is in flight.
  await expect(page.getByRole("button", { name: "Add bean" })).toBeDisabled();
  await expect(page.getByRole("link", { name: "Add bean" })).toHaveCount(0);
  await expect(page.getByText("Offline snapshot")).toHaveCount(0);

  // Once the background refresh resolves, fresh data replaces the cached
  // snapshot and mutation entry points re-enable.
  await expect(page.getByText("Fresh Bean")).toBeVisible({ timeout: 3000 });
  await expect(page.getByText("Cached Bean")).toHaveCount(0);
  await expect(page.getByRole("link", { name: "Add bean" })).toBeVisible();
  await expect(page.getByText("Offline snapshot")).toHaveCount(0);
});

test("a corrupted cached snapshot doesn't strand the app on the loading skeleton", async ({
  page,
  context,
}) => {
  await context.addCookies([
    { name: "dripwatch_session", value: "test", domain: "127.0.0.1", path: "/" },
  ]);
  await context.addInitScript(
    ([snapshotKey, leaseKey, lease]) => {
      // Simulates a truncated/interrupted localStorage write.
      window.localStorage.setItem(snapshotKey as string, "{not valid json");
      window.localStorage.setItem(leaseKey as string, lease as string);
    },
    [
      "dripwatch-notebook-v1",
      "dripwatch-session-lease",
      JSON.stringify({ cacheScope: "test-scope", expiresAt: Date.now() + 3_600_000 }),
    ] as const,
  );
  await page.route("**/api/notebook", (route) =>
    route.fulfill({ json: notebook("Fresh Bean") }),
  );

  await page.goto("/");
  // Must still reach real content via the network fetch, not hang forever
  // on the skeleton because reading the corrupted cache threw before the
  // fetch ever started.
  await expect(page.getByText("Fresh Bean")).toBeVisible({ timeout: 3000 });
});
