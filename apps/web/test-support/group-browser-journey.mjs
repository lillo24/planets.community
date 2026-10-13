// Opt-in real-browser journey. The running Next server and all backend services
// must use the same explicitly disposable loopback fixture stack.
import assert from "node:assert/strict";
import { createRequire } from "node:module";
import { readFile, mkdir, writeFile } from "node:fs/promises";
import { resolve } from "node:path";
const require = createRequire(import.meta.url);
const { chromium } = require(
  process.env.PLANETS_PLAYWRIGHT_PATH ?? "playwright",
);
const defines = JSON.parse(await readFile(process.argv[2], "utf8"));
const base = process.env.GRP03B_WEB_URL ?? "http://127.0.0.1:59830";
for (const value of [base, defines.SUPABASE_URL, defines.GRP03B_MAILPIT])
  assert.ok(
    ["localhost", "127.0.0.1", "[::1]"].includes(new URL(value).hostname),
  );
assert.equal(process.env.PLANETS_DISPOSABLE_QA, "1");
const output = resolve(process.argv[3]);
await mkdir(output, { recursive: true });
const browser = await chromium.launch({ channel: "msedge", headless: true });
const context = await browser.newContext({
  viewport: { width: 390, height: 844 },
});
const page = await context.newPage();
page.setDefaultTimeout(30000);
let step = "preview",
  accepts = 0;
const shot = (name) =>
  page.screenshot({ path: resolve(output, `${name}.png`), fullPage: true });
try {
  const response = await page.goto(`${base}/join/group/${defines.GRP03B_LINK}`);
  assert.match(response.headers()["cache-control"], /no-store/u);
  assert.equal(response.headers()["referrer-policy"], "no-referrer");
  assert.match(response.headers()["x-robots-tag"], /noindex/u);
  await page
    .getByRole("heading", { name: "GRP03B Riverside neighbours" })
    .waitFor();
  await shot("browser-public-preview");
  step = "auth cancel";
  await page.getByText("Sign in to continue", { exact: true }).click();
  await page.getByText("Back to invitation", { exact: true }).click();
  await page.getByText("Sign in to continue", { exact: true }).waitFor();
  step = "real email OTP";
  await page.getByText("Sign in to continue", { exact: true }).click();
  await page
    .getByLabel("Email", { exact: true })
    .fill(defines.GRP03B_BROWSER_EMAIL);
  await page.getByRole("button", { name: "Send code", exact: true }).click();
  await page.getByLabel("Six-digit code").waitFor();
  let otp;
  for (let attempt = 0; attempt < 60 && !otp; attempt++) {
    const result = await fetch(
      `${defines.GRP03B_MAILPIT}/api/v1/search?query=${encodeURIComponent(`to:${defines.GRP03B_BROWSER_EMAIL}`)}&limit=10`,
    ).then((r) => r.json());
    const message = result.messages?.[0];
    if (message) {
      const body = await fetch(
        `${defines.GRP03B_MAILPIT}/api/v1/message/${encodeURIComponent(message.ID)}`,
      ).then((r) => r.json());
      otp = `${body.Text ?? ""} ${body.HTML ?? ""}`.match(
        /(?:^|\D)(\d{6})(?:\D|$)/u,
      )?.[1];
    }
    if (!otp) await new Promise((r) => setTimeout(r, 250));
  }
  assert.ok(otp, "Fictional OTP email must arrive.");
  await page.getByLabel("Six-digit code").fill(otp);
  await page.getByRole("button", { name: "Verify code", exact: true }).click();
  step = "photo-free profile and cancellation";
  await page.getByText("Complete profile", { exact: true }).waitFor();
  await page.getByText("Complete profile", { exact: true }).click();
  await page.getByText("Cancel profile setup", { exact: true }).click();
  await page.getByText("Complete profile", { exact: true }).click();
  await page
    .getByLabel("Name", { exact: true })
    .fill("Fictional browser neighbour");
  assert.equal(
    await page.getByText("Profile photo", { exact: true }).count(),
    0,
  );
  await page.getByRole("button", { name: "Continue", exact: true }).click();
  await page.getByRole("button", { name: "Join group", exact: true }).waitFor();
  assert.equal(accepts, 0);
  step = "policy and response loss";
  await page.getByRole("checkbox", { name: /I accept the/u }).check();
  await page.route(
    "**/rest/v1/rpc/accept_group_participant_invitation",
    async (route) => {
      accepts++;
      if (accepts === 1) {
        await route.fetch();
        await route.abort("failed");
      } else await route.continue();
    },
  );
  await page.getByRole("button", { name: "Join group", exact: true }).click();
  await page.getByRole("button", { name: "Retry original action" }).waitFor();
  await page.getByRole("button", { name: "Retry original action" }).click();
  await page.waitForURL(/\/joined\/groups\/[0-9a-f-]+$/u);
  await page
    .getByText("You are part of this group.", { exact: true })
    .waitFor();
  assert.equal(accepts, 1, "Recovery must not admit again.");
  assert.ok(!page.url().includes(defines.GRP03B_LINK));
  await shot("browser-participant-confirmed");
  step = "informed authority acceptance";
  await page.goto(`${base}/invite/group/${defines.GRP03B_BROWSER_AUTHORITY}`);
  await page.getByText("Co-organizer", { exact: true }).waitFor();
  const accept = page.getByRole("button", {
    name: "Accept organizer role",
    exact: true,
  });
  assert.equal(await accept.isDisabled(), true);
  await page
    .getByRole("checkbox", {
      name: "I understand and accept this organizer role.",
    })
    .check();
  await shot("browser-authority-consent");
  await accept.click();
  await page.waitForURL(/\/joined\/groups\/[0-9a-f-]+$/u);
  await page
    .getByText("Your Co-organizer role is active.", { exact: true })
    .waitFor();
  await shot("browser-authority-confirmed");
  step = "strict capability routes";
  for (const path of [
    `/join/group/${defines.GRP03B_LINK}?unexpected=1`,
    `/join/%67roup/${defines.GRP03B_LINK}`,
  ]) {
    const invalid = await context.request.get(`${base}${path}`);
    assert.equal(invalid.status(), 404);
  }
  await writeFile(
    resolve(output, "result.json"),
    JSON.stringify(
      {
        passed: true,
        genuineOtp: true,
        participantAcceptCalls: accepts,
        tokenFreeConfirmation: true,
        screenshots: 4,
      },
      null,
      2,
    ),
  );
  console.log(
    "Real browser journey passed: OTP, profile/cancel, policy, lost-response recovery, token-free confirmation and informed organizer acceptance.",
  );
} catch {
  // Never let browser diagnostics include capability-bearing URLs or account data.
  await shot("browser-failure").catch(() => {});
  console.error(`Group browser journey failed at: ${step}.`);
  process.exitCode = 1;
} finally {
  await context.close();
  await browser.close();
}
