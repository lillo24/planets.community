import assert from "node:assert/strict";
import { readFileSync, writeFileSync } from "node:fs";
import {
  outputFile,
  cloudflareToken,
  workerName,
  accountId,
} from "./worker-cpu-lib.mjs";
const label = process.argv[2];
const input = JSON.parse(
  readFileSync(outputFile(label, "hosted-windows.json")),
);
assert.equal(input.worker, workerName);
assert(/^[a-f0-9-]{36}$/.test(input.version));
for (const w of input.windows) {
  assert(
    /^\d{4}-\d{2}-\d{2}T[\d:.]+Z$/.test(w.start) &&
      /^\d{4}-\d{2}-\d{2}T[\d:.]+Z$/.test(w.end),
    "Invalid measurement window",
  );
}
const token = cloudflareToken();
const aliases = input.windows
  .map(
    (w, i) =>
      `w${i}: workersInvocationsAdaptive(limit:100,filter:{scriptName:"${input.worker}",scriptVersion:"${input.version}",datetime_geq:"${w.start}",datetime_leq:"${w.end}"}){sum{requests errors subrequests} avg{sampleInterval} quantiles{cpuTimeP50 cpuTimeP95} max{cpuTime} dimensions{scriptVersion status}}`,
  )
  .join("\n");
const response = await fetch("https://api.cloudflare.com/client/v4/graphql", {
  method: "POST",
  headers: {
    Authorization: `Bearer ${token}`,
    "Content-Type": "application/json",
  },
  body: JSON.stringify({
    query: `query{viewer{accounts(filter:{accountTag:"${accountId}"}){${aliases}}}}`,
  }),
});
assert(response.ok, `Metrics HTTP ${response.status}`);
const data = await response.json();
assert(
  !data.errors,
  "Cloudflare rejected the aggregate metrics query; check token access and analytics availability.",
);
const account = data.data.viewer.accounts[0];
const result = {
  ...input,
  metricsFetched: new Date().toISOString(),
  windows: input.windows.map((w, i) => ({ ...w, metrics: account["w" + i] })),
};
writeFileSync(
  outputFile(label, "hosted-metrics.json"),
  JSON.stringify(result, null, 2),
);
console.log(JSON.stringify(result, null, 2));
