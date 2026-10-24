// Synchronous loopback handshake. Native SDK screenshot callbacks run after test
// completion, so they cannot coordinate system settings during a journey.
import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import { createServer } from "node:http";
import { mkdir, writeFile } from "node:fs/promises";
import path from "node:path";
import { promisify } from "node:util";
assert.equal(process.env.GITHUB_ACTIONS, "true");
assert.equal(process.env.RUNNER_ENVIRONMENT, "github-hosted");
assert.equal(process.env.PLANETS_DISPOSABLE_QA, "1");
const directory = path.resolve(process.argv[2]);
assert.equal(directory, path.join(process.cwd(), "a1-native-evidence"));
await mkdir(directory, { recursive: true });
const execute = promisify(execFile);
async function adb(args, binary = false) {
  const { stdout } = await execute("adb", ["-s", "emulator-5554", ...args], {
    encoding: binary ? "buffer" : "utf8",
    timeout: 20000,
    maxBuffer: 20 * 1024 * 1024,
  });
  return binary ? stdout : stdout.trim();
}
const names = new Set([
  "before-it-dark-private",
  "after-it-dark-private",
  "after-it-dark-thread",
  "after-it-dark-keyboard",
  "after-en-light-private",
  "after-en-light-narrow-2x",
  "after-marco-received",
]);
const seen = new Set(),
  metadata = { before: [], after: [] };
let busy = false;
const server = createServer(async (req, res) => {
  res.setHeader("content-type", "application/json");
  if (req.method === "GET" && req.url === "/health") {
    res.end('{"ready":true}');
    return;
  }
  const name = req.url?.startsWith("/capture/")
    ? req.url.slice("/capture/".length)
    : null;
  if (req.method !== "POST" || !names.has(name)) {
    res.writeHead(400);
    res.end('{"error":"Unknown A1 checkpoint"}');
    return;
  }
  if (busy || seen.has(name)) {
    res.writeHead(409);
    res.end('{"error":"Repeated or concurrent A1 checkpoint"}');
    return;
  }
  busy = true;
  req.resume();
  try {
    const png = await adb(["exec-out", "screencap", "-p"], true);
    assert.equal(png.subarray(0, 8).toString("hex"), "89504e470d0a1a0a");
    await writeFile(path.join(directory, name + ".png"), png, { flag: "wx" });
    const lane = name.startsWith("before-") ? "before" : "after";
    metadata[lane].push({
      name,
      fictional: true,
      avdProfile: "pixel_4",
      wmSize: await adb(["shell", "wm", "size"]),
      wmDensity: await adb(["shell", "wm", "density"]),
      fontScale: await adb([
        "shell",
        "settings",
        "get",
        "system",
        "font_scale",
      ]),
      nightMode: await adb(["shell", "cmd", "uimode", "night"]),
      device: await adb(["shell", "getprop", "ro.product.model"]),
    });
    await writeFile(
      path.join(directory, `captures-${lane}.json`),
      JSON.stringify(metadata[lane]),
    );
    if (name === "after-it-dark-keyboard") {
      await adb(["shell", "input", "keyevent", "KEYCODE_BACK"]);
      await adb(["shell", "cmd", "uimode", "night", "no"]);
    }
    if (name === "after-en-light-private") {
      await adb(["shell", "wm", "size", "960x2160"]);
      await adb(["shell", "settings", "put", "system", "font_scale", "2.0"]);
    }
    if (name === "after-en-light-narrow-2x") {
      await adb(["shell", "wm", "size", "1280x2856"]);
      await adb(["shell", "settings", "put", "system", "font_scale", "1.0"]);
    }
    seen.add(name);
    res.end('{"captured":true}');
  } catch (error) {
    console.error(
      JSON.stringify({ checkpoint: name, error: error.code ?? error.name }),
    );
    res.writeHead(500);
    res.end('{"error":"Owned Android checkpoint failed"}');
  } finally {
    busy = false;
  }
});
server.requestTimeout = 60000;
server.headersTimeout = 10000;
await new Promise((resolve, reject) => {
  server.once("error", reject);
  server.listen(61325, "127.0.0.1", resolve);
});
console.log("A1 checkpoint server ready on owned loopback 61325.");
