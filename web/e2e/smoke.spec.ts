import { expect,test } from "@playwright/test";
test("unauthenticated visitors see the shared passcode gate",async({page})=>{await page.goto("/");await expect(page).toHaveURL(/\/login/);await expect(page.getByRole("heading",{name:"DripWatch"})).toBeVisible();await expect(page.getByLabel("Shared passcode")).toBeVisible()});
test("manifest is valid",async({request})=>{const response=await request.get("/manifest.webmanifest");expect(response.ok()).toBeTruthy();expect((await response.json()).display).toBe("standalone")});
