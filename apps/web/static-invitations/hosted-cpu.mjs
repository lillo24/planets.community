import assert from "node:assert/strict";
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import {
  accountId,
  workerName,
  hostedOrigin,
  currentVersion,
  cloudflareToken,
} from "./cloudflare.mjs";
const mode = process.argv[2];
assert(["measure", "read"].includes(mode));
const dir = fileURLToPath(
  new URL("../.wrangler/link-host03/", import.meta.url),
);
mkdirSync(dir, { recursive: true });
const windowFile = `${dir}/hosted-cpu-windows.json`;
if (mode === "measure") {
  const version = await currentVersion();
  const windows = [];
  async function window(name, path, n = 30, method = "GET") {
    const start = new Date().toISOString();
    let errors = 0;
    let lastBody = "";
    for (let i = 0; i < n; i++) {
      const r = await fetch(hostedOrigin + path, {
        method,
        redirect: "manual",
        signal: AbortSignal.timeout(20000),
      });
      lastBody = await r.text();
      if (
        r.status !==
        (method === "POST" ? 405 : name.includes("404") ? 404 : 200)
      )
        errors++;
    }
    const row = { name, start, end: new Date().toISOString(), sent: n, errors };
    windows.push(row);
    writeFileSync(
      windowFile,
      JSON.stringify({ worker: workerName, version, windows }, null, 2),
    );
    console.log(JSON.stringify(row));
    assert.equal(errors, 0);
    await new Promise((resolve) => setTimeout(resolve, 2200));
    return lastBody;
  }
  const html = await window("first-observed-auth", "/auth", 1);
  const asset = html.match(/src="(\/assets\/[^"\s]+\.js)"/u)?.[1];
  assert(asset);
  const cases = [
    ["auth", "/auth"],
    ["invite", "/join/project/" + "a".repeat(43)],
    ["confirmation", "/joined/proposals/fb030300-0000-4000-8000-000000000002"],
    ["asset", asset],
    ["404", "/admin"],
    ["method", "/auth"],
  ];
  for (const pass of ["initial-repeat", "later-repeat"])
    for (const [name, path] of cases)
      await window(
        `${pass}-${name}`,
        path,
        30,
        name === "method" ? "POST" : "GET",
      );
  assert.equal(
    await currentVersion(),
    version,
    "Deployment changed during measurement.",
  );
} else {
  const input = JSON.parse(readFileSync(windowFile, "utf8"));
  assert.equal(input.worker, workerName);
  assert(/^[a-f0-9-]{36}$/u.test(input.version));
  const aliases = input.windows
    .map((w, i) => {
      assert(
        /^\d{4}-\d{2}-\d{2}T[\d:.]+Z$/u.test(w.start) &&
          /^\d{4}-\d{2}-\d{2}T[\d:.]+Z$/u.test(w.end),
      );
      return `w${i}:workersInvocationsAdaptive(limit:100,filter:{scriptName:"${workerName}",scriptVersion:"${input.version}",datetime_geq:"${w.start}",datetime_leq:"${w.end}"}){sum{requests errors} avg{sampleInterval} quantiles{cpuTimeP50 cpuTimeP95} max{cpuTime} dimensions{status}}`;
    })
    .join("\n");
  const r = await fetch("https://api.cloudflare.com/client/v4/graphql", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${cloudflareToken()}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      query: `query{viewer{accounts(filter:{accountTag:"${accountId}"}){${aliases}}}}`,
    }),
  });
  assert(r.ok, `Metrics HTTP ${r.status}`);
  const data = await r.json();
  assert(!data.errors, "Aggregate metrics unavailable.");
  const result = {
    ...input,
    fetchedAt: new Date().toISOString(),
    units: "Cloudflare CPU fields are microseconds; divide by 1000 for ms",
    windows: input.windows.map((w, i) => ({
      ...w,
      metrics: data.data.viewer.accounts[0][`w${i}`],
    })),
  };
  writeFileSync(`${dir}/hosted-cpu.json`, JSON.stringify(result, null, 2));
  console.log(JSON.stringify(result, null, 2));
}
