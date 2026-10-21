// Only bounded synthetic PNGs and allowlisted metadata become public artifacts.
import assert from "node:assert/strict";
import { readFile, readdir, mkdir, writeFile } from "node:fs/promises";
import { createHash } from "node:crypto";
import { execFileSync } from "node:child_process";
import path from "node:path";
import os from "node:os";

const [directory, result, phase] = process.argv.slice(2);
assert.equal(process.env.GITHUB_ACTIONS, "true");
assert.equal(process.env.RUNNER_ENVIRONMENT, "github-hosted");
const relative = path.relative(os.tmpdir(), path.resolve(directory));
assert.ok(relative && !relative.startsWith("..") && !path.isAbsolute(relative));
assert.match(result, /^\d+$/); assert.match(phase, /^[a-z-]+$/);
const output = path.resolve("mock-native-evidence");
await mkdir(output, { recursive: true });
const allowed = new Set(["native-result.json", "apk-scan.json", "failure.json"]);
const files = [];
for (const name of await readdir(output)) {
  assert.ok(/^[a-z][a-z0-9-]{3,90}\.png$/.test(name) || allowed.has(name), "Unexpected evidence file");
  const bytes = await readFile(path.join(output, name));
  assert.ok(bytes.length <= 8 * 1024 * 1024);
  if (name.endsWith(".png")) {
    assert.equal(bytes.subarray(0, 8).toString("hex"), "89504e470d0a1a0a");
    files.push({ name, sha256: createHash("sha256").update(bytes).digest("hex") });
  } else {
    const text = bytes.toString("utf8");
    assert.ok(!/sb_(?:secret|publishable)_[A-Za-z0-9_-]+|Bearer\s+\S+|eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\./.test(text), "Credential-shaped evidence");
    JSON.parse(text);
  }
}
const source = execFileSync("git", ["rev-parse", "HEAD"], { encoding: "utf8" }).trim();
if (result !== "0") {
  let details = {};
  try { details = JSON.parse(await readFile(path.join(directory, "native-failure.json"), "utf8")); }
  catch (error) { if (error.code !== "ENOENT") throw error; }
  let diagnostics = [];
  try {
    const log = await readFile(path.join(directory, `${phase}.log`), "utf8");
    const privateValues = JSON.parse(await readFile(path.join(directory, "scan-secrets.json"), "utf8"));
    privateValues.push(process.env.PLANETS_MOCK_QA_PASSWORD ?? "");
    diagnostics = log.split(/\r?\n/).filter((line) => /\.dart:\d+:\d+: Error:|^FAILURE:|^Error:|^Execution failed for task|^> /.test(line)).slice(-18).map((line) => {
      for (const value of privateValues) if (value.length > 12) line = line.replaceAll(value, "[redacted]");
      return line.replace(/sb_(?:secret|publishable)_[A-Za-z0-9_-]+|eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+|Bearer\s+\S+/g, "[redacted]").slice(0, 500);
    });
  } catch (error) { if (error.code !== "ENOENT") throw error; }
  await writeFile(path.join(output, "failure.json"), JSON.stringify({ source, phase, success: false, ...details, diagnostics }, null, 2) + "\n");
}
await writeFile(path.join(output, "provenance.json"), JSON.stringify({ source, phase,
  success: result === "0", mode: "release", device: "CI-owned emulator-5554; 320dp; 2x text",
  physicalDeviceUsed: false, hostedProof: false, uploadReady: false, files }, null, 2) + "\n");
if (result === "0") {
  const native = JSON.parse(await readFile(path.join(output, "native-result.json"), "utf8"));
  assert.equal(native.success, true); assert.equal(native.source, source);
  assert.equal(native.processRestart, true); assert.equal(native.network.forbiddenNormalProductCalls, 0);
  assert.ok(files.length >= 10);
  assert.equal(JSON.parse(await readFile(path.join(output, "apk-scan.json"), "utf8")).success, true);
}
console.log(`Mock native evidence: ${result === "0" ? "passed" : "failed"}; phase=${phase}; PNGs=${files.length}. No raw logs, APK, tokens or private defines exported.`);
