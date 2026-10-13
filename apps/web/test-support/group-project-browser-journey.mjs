// Opt-in anonymous, read-only journey against the same disposable Android fixture.
import assert from "node:assert/strict";
import { createRequire } from "node:module";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import { resolve } from "node:path";
const require = createRequire(import.meta.url);
const { chromium } = require(
  process.env.PLANETS_PLAYWRIGHT_PATH ?? "playwright",
);
const defines = JSON.parse(await readFile(process.argv[2], "utf8"));
const base = process.env.GRP03C_WEB_URL ?? "http://127.0.0.1:16830";
assert.equal(process.env.PLANETS_DISPOSABLE_QA, "1");
for (const endpoint of [base, defines.SUPABASE_URL])
  assert.ok(
    ["localhost", "127.0.0.1", "[::1]"].includes(new URL(endpoint).hostname),
  );
const response = await fetch(
  `${defines.SUPABASE_URL}/rest/v1/rpc/list_public_group_projects`,
  {
    method: "POST",
    headers: {
      apikey: defines.SUPABASE_PUBLISHABLE_KEY,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ p_group_id: defines.GRP03C_GROUP, p_limit: 20 }),
  },
);
assert.ok(response.ok, "Public group feed is readable without an account.");
const projects = await response.json();
assert.equal(projects.length, 1, "Only the published scratch Project appears.");
const project = projects[0];
const output = resolve(process.argv[3]);
await mkdir(output, { recursive: true });
const browser = await chromium.launch({ channel: "msedge", headless: true });
const failures = [];
try {
  for (const width of [390, 320]) {
    const context = await browser.newContext({
      viewport: { width, height: 844 },
    });
    const page = await context.newPage();
    page.setDefaultTimeout(60000);
    page.on("pageerror", (error) => failures.push(error.message));
    const shot = async (name) => {
      assert.equal(
        await page.evaluate(
          () => document.documentElement.scrollWidth > innerWidth,
        ),
        false,
        "No horizontal overflow.",
      );
      await page.screenshot({
        path: resolve(output, `browser-${width}-${name}.png`),
        fullPage: true,
      });
    };
    await page.goto(`${base}/groups/${defines.GRP03C_GROUP}`);
    await page
      .getByRole("heading", { name: "Fictional Neighbourhood Garden" })
      .waitFor();
    const card = page.getByRole("link", { name: project.title, exact: true });
    await card.waitFor();
    await shot("group-feed");
    await card.click();
    await page.waitForURL(`**/proposals/${project.project_id}`);
    await page
      .getByRole("heading", { name: project.title, exact: true })
      .waitFor();
    const badge = page.getByRole("link", {
      name: /For Fictional Neighbourhood Garden/,
    });
    await badge.waitFor();
    await shot("project-badge");
    await badge.click();
    await page.waitForURL(`**/groups/${defines.GRP03C_GROUP}`);
    await page
      .getByRole("link", { name: project.title, exact: true })
      .waitFor();
    await page.goto(`${base}/proposals/${project.project_id}?intent=join`);
    await page
      .getByRole("link", { name: /For Fictional Neighbourhood Garden/ })
      .waitFor();
    await shot("ordinary-share");
    await page.goto(`${base}/joined/proposals/${project.project_id}`);
    await page
      .getByText("Sign in to check your participation in this Project.", {
        exact: true,
      })
      .waitFor();
    await shot("signed-out-confirmation");
    await page
      .getByRole("link", { name: "View public Project", exact: true })
      .click();
    await page
      .getByRole("link", { name: /For Fictional Neighbourhood Garden/ })
      .waitFor();
    await context.close();
  }
  assert.deepEqual(failures, [], "No browser runtime errors.");
  await writeFile(
    resolve(output, "journey.json"),
    JSON.stringify(
      {
        widths: [390, 320],
        publicProject: project.project_id,
        publicGroup: defines.GRP03C_GROUP,
        assertions:
          "anonymous feed, normal detail, ordinary share, signed-out confirmation, return navigation and no horizontal overflow",
        runtimeErrors: failures,
      },
      null,
      2,
    ),
  );
  console.log(
    "Read-only browser journey passed at 390px and 320px: group feed, attribution, ordinary share, signed-out confirmation and return navigation.",
  );
} finally {
  await browser.close();
}
