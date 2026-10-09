import assert from "node:assert/strict";
import { writeFileSync } from "node:fs";
import {
  outputFile,
  cloudflareToken,
  currentVersion,
  workerName,
  hostedOrigin,
  probeCases,
  canonicalizeRsc,
  validateResponse,
} from "./worker-cpu-lib.mjs";
const label = process.argv[2];
outputFile(label, "hosted-windows.json");
const token = cloudflareToken();
const worker = workerName,
  origin = hostedOrigin;
const version = await currentVersion(token);
const response = await fetch(origin + "/auth");
const html = await response.text();
assert.equal(response.status, 200);
const asset = html.match(/(?:src|href)="(\/_next\/static\/[^"\s]+)"/)?.[1];
assert(asset);
const specs = probeCases(asset);
if (process.argv[3])
  assert(
    specs.some((s) => s.name === process.argv[3]),
    "Unknown route class",
  );
const windows = [];
for (const spec of specs) {
  const { name } = spec;
  if (process.argv[3] && name !== process.argv[3]) continue;
  if (name === "rsc") await canonicalizeRsc(origin, spec);
  await new Promise((r) => setTimeout(r, 2200));
  const start = new Date().toISOString();
  let errors = 0;
  const statuses = {};
  for (let i = 0; i < 30; i++) {
    try {
      const response = await fetch(origin + spec.path, {
        headers: spec.headers,
        redirect: "manual",
        signal: AbortSignal.timeout(30000),
      });
      const body = await response.text();
      statuses[response.status] = (statuses[response.status] || 0) + 1;
      validateResponse(spec, response, body);
    } catch {
      errors++;
    }
  }
  const row = {
    name,
    start,
    end: new Date().toISOString(),
    sent: 30,
    errors,
    statuses,
  };
  windows.push(row);
  console.log(JSON.stringify(row));
  writeFileSync(
    outputFile(label, "hosted-windows.json"),
    JSON.stringify({ label, worker, version, windows }, null, 2),
  );
}
assert.equal(
  await currentVersion(token),
  version,
  "Deployment changed during measurement",
);
if (windows.some((w) => w.errors)) process.exitCode = 1;
