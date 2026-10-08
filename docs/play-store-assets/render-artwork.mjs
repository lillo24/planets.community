import { mkdir } from "node:fs/promises";
import { createRequire } from "node:module";
import { dirname, join } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

// Use an existing Playwright installation, including the desktop bundled runtime.
// PLAYWRIGHT_MODULE is an optional absolute path to its package directory.
const require = createRequire(import.meta.url);
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || "playwright");
const root = dirname(fileURLToPath(import.meta.url));
if (process.platform !== "win32") {
  throw new Error(
    "Render on Windows with Segoe UI to preserve the website typography.",
  );
}
const output = join(root, ".rendered");
await mkdir(output, { recursive: true });
const browser = await chromium.launch({
  headless: true,
  channel: process.env.PLAYWRIGHT_BROWSER || "chrome",
});
try {
  for (const [name, width, height] of [
    ["app-icon", 512, 512],
    ["feature-graphic", 1024, 500],
  ]) {
    const page = await browser.newPage({
      viewport: { width, height },
      deviceScaleFactor: 2,
      colorScheme: "light",
    });
    await page.goto(pathToFileURL(join(root, "artwork", `${name}.svg`)).href);
    await page.evaluate(() => document.fonts.ready);
    // Fail if an artwork dependency did not decode; do not export empty imagery.
    await page.evaluate(async () => {
      for (const node of document.querySelectorAll("image")) {
        const image = new Image();
        image.src = new URL(node.getAttribute("href"), location.href).href;
        await image.decode();
      }
    });
    await page.screenshot({ path: join(output, `${name}.png`) });
    await page.close();
  }
} finally {
  await browser.close();
}
console.log("Rendered both editable SVG artworks at 2x resolution.");
