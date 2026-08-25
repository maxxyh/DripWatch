import { expect, test } from "@playwright/test";

const bean = (id: string, name: string) => ({
  id,
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

const brew = (
  id: string,
  bean_id: string,
  method_raw: "pourover" | "espresso",
) => ({
  id,
  created_at: "2026-01-01T00:00:00.000Z",
  updated_at: "2026-01-01T00:00:00.000Z",
  deleted_at: null,
  brewed_at: "2026-01-01T00:00:00.000Z",
  method_raw,
  brewers: [],
  recipe: { pours: [] },
  taste: { positives: [], negatives: [], balance: {} },
  next_recipe_draft: null,
  photo_path: null,
  bean_id,
});

const notebook = () => ({
  beans: [
    bean("00000000-0000-4000-8000-000000000001", "Pourover Bean"),
    bean("00000000-0000-4000-8000-000000000002", "Espresso Bean"),
  ],
  brews: [
    brew(
      "00000000-0000-4000-8000-000000000011",
      "00000000-0000-4000-8000-000000000001",
      "pourover",
    ),
    brew(
      "00000000-0000-4000-8000-000000000012",
      "00000000-0000-4000-8000-000000000002",
      "espresso",
    ),
  ],
  beanPhotos: [],
  grinders: [],
  loadedAt: new Date().toISOString(),
});

test("shelf search, sort, and method filters persist across reload", async ({
  page,
  context,
}) => {
  const data = notebook();
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
      JSON.stringify(data),
      JSON.stringify({ cacheScope: "test-scope", expiresAt: Date.now() + 3_600_000 }),
    ] as const,
  );
  await page.route("**/api/notebook", (route) => route.fulfill({ json: data }));

  await page.goto("/");
  await expect(page.getByText("Pourover Bean")).toBeVisible();
  await expect(page.getByText("Espresso Bean")).toBeVisible();

  // Apply search, method filter, sort, and direction.
  await page.getByLabel("Search beans by name").fill("Espresso");
  await expect(page.getByText("Pourover Bean")).toHaveCount(0);
  await expect(page.getByText("Espresso Bean")).toBeVisible();

  await page.getByRole("button", { name: "Espresso", pressed: false }).click();
  await expect(page.getByRole("button", { name: "Espresso", pressed: true })).toBeVisible();

  await page.getByRole("combobox", { name: /sort by/i }).click();
  await page.getByRole("option", { name: "Name" }).click();
  await page.getByRole("button", { name: "Ascending" }).click();
  await expect(page.getByRole("button", { name: "Descending" })).toBeVisible();

  // Reload and confirm the filters are restored.
  await page.reload();
  await expect(page.getByLabel("Search beans by name")).toHaveValue("Espresso");
  await expect(page.getByRole("button", { name: "Espresso", pressed: true })).toBeVisible();
  await expect(page.getByRole("button", { name: "Descending" })).toBeVisible();
  await expect(page.getByText("Pourover Bean")).toHaveCount(0);
  await expect(page.getByText("Espresso Bean")).toBeVisible();
});

test("logout clears persisted shelf filters", async ({ page, context }) => {
  const data = notebook();
  await context.addCookies([
    { name: "dripwatch_session", value: "test", domain: "127.0.0.1", path: "/" },
  ]);
  await context.addInitScript(
    ([snapshotKey, leaseKey, snapshot, lease, filtersKey, filters]) => {
      window.localStorage.setItem(snapshotKey as string, snapshot as string);
      window.localStorage.setItem(leaseKey as string, lease as string);
      window.localStorage.setItem(filtersKey as string, filters as string);
    },
    [
      "dripwatch-notebook-v1",
      "dripwatch-session-lease",
      JSON.stringify(data),
      JSON.stringify({ cacheScope: "test-scope", expiresAt: Date.now() + 3_600_000 }),
      "dripwatch-shelf-filters-v1",
      JSON.stringify({ q: "Espresso", method: "espresso", sort: "name", dir: "desc" }),
    ] as const,
  );
  await page.route("**/api/auth/logout", (route) => route.fulfill({ status: 200 }));
  await page.route("**/api/notebook", (route) => route.fulfill({ json: data }));

  await page.goto("/");
  await expect(page.getByLabel("Search beans by name")).toHaveValue("Espresso");

  await page.getByRole("button", { name: "Log out" }).click();
  await expect(page).toHaveURL(/\/login/);

  const filtersCleared = await page.evaluate((key) => {
    return window.localStorage.getItem(key);
  }, "dripwatch-shelf-filters-v1");
  expect(filtersCleared).toBeNull();
});
